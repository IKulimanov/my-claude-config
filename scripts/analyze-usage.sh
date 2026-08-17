#!/usr/bin/env bash
# Анализирует ~/.claude/logs/*.jsonl и печатает сводку по использованию Claude.
# Показывает: топ инструментов, топ агентов, топ skills, токены по дням/проектам.
#
# Использование:
#   ./scripts/analyze-usage.sh              # вся история
#   ./scripts/analyze-usage.sh 7            # последние 7 дней
#   ./scripts/analyze-usage.sh 7 my-project # последние 7 дней, только этот проект

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/usage-lib.sh
. "$SCRIPT_DIR/lib/usage-lib.sh"

LOG_DIR="$(usage_log_dir)"
DAYS="${1:-0}"        # 0 = вся история
PROJECT="${2:-}"      # пусто = все проекты

if [ ! -d "$LOG_DIR" ]; then
  echo "No logs found at $LOG_DIR. Запусти Claude несколько раз с установленными хуками." >&2
  exit 1
fi

# Граница времени
if [ "$DAYS" -gt 0 ]; then
  SINCE=$(date -u -v-"${DAYS}d" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "${DAYS} days ago" +"%Y-%m-%dT%H:%M:%SZ")
else
  SINCE="0000-00-00T00:00:00Z"
fi

# Helper: фильтр по времени и проекту (общая логика в lib/usage-lib.sh).
filter() {
  usage_filter_range "$1" "$SINCE" "" "$PROJECT"
}

bar() { printf '%*s\n' 60 '' | tr ' ' '─'; }

echo "Claude usage report"
[ "$DAYS" -gt 0 ] && echo "Period: last $DAYS days (since $SINCE)" || echo "Period: all time"
[ -n "$PROJECT" ] && echo "Project filter: $PROJECT"
bar

echo
echo "▎Sessions"
SESSIONS_F=$(filter "$LOG_DIR/sessions.jsonl")
echo "  starts: $(echo "$SESSIONS_F" | jq -c 'select(.event=="SessionStart")' | wc -l | tr -d ' ')"
echo "  ends:   $(echo "$SESSIONS_F" | jq -c 'select(.event=="SessionEnd")' | wc -l | tr -d ' ')"
echo "  по проектам:"
echo "$SESSIONS_F" | jq -r 'select(.event=="SessionStart") | .project // "?"' | sort | uniq -c | sort -rn | head -10 | awk '{printf "    %4d  %s\n", $1, $2}'

echo
echo "▎Top инструменты (tool calls)"
filter "$LOG_DIR/tools.jsonl" | jq -r 'select(.phase=="pre") | .tool' | sort | uniq -c | sort -rn | head -15 | awk '{printf "  %5d  %s\n", $1, $2}'

echo
echo "▎Top subagents (Agent tool calls)"
filter "$LOG_DIR/subagents.jsonl" | jq -r 'select(.event=="SubagentStart") | .agent_type // "(unspecified)"' | sort | uniq -c | sort -rn | head -15 | awk '{printf "  %5d  %s\n", $1, $2}'

echo
# Skills грузятся через инструмент Skill (а не InstructionsLoaded — тот фиксирует
# только CLAUDE.md/память). Поэтому источник — Skill-вызовы из tools.jsonl.
echo "▎Top skills (Skill-вызовы из tools.jsonl)"
filter "$LOG_DIR/tools.jsonl" | jq -r 'select(.phase=="pre" and .tool=="Skill") | .input.skill // "(unknown)"' | sort | uniq -c | sort -rn | head -15 | awk '{printf "  %5d  %s\n", $1, $2}'

echo
echo "▎Slash-команды"
# Берём только первую строку значения и требуем форму команды (/token целиком):
# защищает отчёт от старых повреждённых записей (многострочный промпт «протекал»
# в slash_command) и от путей вроде /Users/... , попавших в поле.
filter "$LOG_DIR/prompts.jsonl" | jq -r --arg re "$USAGE_SLASH_RE" 'select(.slash_command != null and .slash_command != "") | (.slash_command | split("\n")[0]) | select(test($re))' | sort | uniq -c | sort -rn | head -15 | awk '{printf "  %5d  %s\n", $1, $2}'

echo
echo "▎Токены"
# Строки stops.jsonl кумулятивны в рамках сессии (каждый Stop пересуммирует
# весь транскрипт) — наивная сумма строк завышает расход на порядки.
# Сумма сессии за период = (последний стоп в периоде) - (последний стоп до него).
STOPS_SESS=$(
  { [ -f "$LOG_DIR/stops.jsonl" ] && jq -cR 'fromjson? | select(.ts != null)' "$LOG_DIR/stops.jsonl"; } \
  | jq -s --arg since "$SINCE" --arg proj "$PROJECT" '
    [.[] | select($proj == "" or .project == $proj)]
    | group_by(.session)
    | map(
        sort_by(.ts)
        | last as $in_row
        | (map(select(.ts < $since)) | last) as $before
        | select($in_row.ts >= $since)
        | {
            project: ($in_row.project // "?"),
            input:       (($in_row.input_tokens // 0) - ($before.input_tokens // 0)),
            output:      (($in_row.output_tokens // 0) - ($before.output_tokens // 0)),
            cache_read:  (($in_row.cache_read // 0)   - ($before.cache_read // 0)),
            cache_write: (($in_row.cache_write // 0)  - ($before.cache_write // 0)),
            turns:       (($in_row.turns // 0)        - ($before.turns // 0))
          }
      )'
)
echo "$STOPS_SESS" | jq -r '
  "  sessions analyzed: \(length)",
  "  input:  \(map(.input) | add // 0) tokens",
  "  output: \(map(.output) | add // 0) tokens",
  "  cache_read:  \(map(.cache_read) | add // 0)",
  "  cache_write: \(map(.cache_write) | add // 0)",
  "  turns total: \(map(.turns) | add // 0)"
'

echo
echo "▎Топ-5 проектов по токенам (input+output)"
echo "$STOPS_SESS" | jq -r '
  group_by(.project)
  | map({project:.[0].project, tokens: (map(.input + .output) | add)})
  | sort_by(-.tokens)
  | .[0:5]
  | .[]
  | "  \(.tokens)\t\(.project)"
' | awk -F'\t' '{printf "  %10s  %s\n", $1, $2}'

echo
echo "▎TDD-сигнал (правки/запуски тестов из tools.jsonl)"
# Косвенная проверка iron-law TDD: сколько правок попадает в тест-файлы против
# прод-файлов и как часто реально запускались тесты. Считаем по уже имеющимся
# полям tools.jsonl (file_path / command) — отдельное логирование не нужно.
TDD_F=$(filter "$LOG_DIR/tools.jsonl")
TEST_RE="$USAGE_TEST_RE"
RUN_RE="$USAGE_RUN_RE"
test_edits=$(echo "$TDD_F" | jq -rc --arg re "$TEST_RE" 'select(.phase=="pre" and (.tool=="Edit" or .tool=="Write" or .tool=="MultiEdit")) | (.input.file_path // "") | select(. != "" and test($re))' | grep -c '' || true)
prod_edits=$(echo "$TDD_F" | jq -rc --arg re "$TEST_RE" 'select(.phase=="pre" and (.tool=="Edit" or .tool=="Write" or .tool=="MultiEdit")) | (.input.file_path // "") | select(. != "" and (test($re)|not))' | grep -c '' || true)
test_runs=$(echo "$TDD_F" | jq -rc --arg re "$RUN_RE" 'select(.phase=="pre" and .tool=="Bash") | (.input.command // "") | select(. != "" and test($re))' | grep -c '' || true)
printf '  правки тест-файлов:  %s\n' "$test_edits"
printf '  правки прод-файлов:  %s\n' "$prod_edits"
printf '  запуски тестов:      %s\n' "$test_runs"

echo
echo "▎Заблокированные действия"
BLOCKS_F=$(filter "$LOG_DIR/blocks.jsonl" 2>/dev/null || true)
if [ -n "$BLOCKS_F" ]; then
  echo "$BLOCKS_F" | jq -r '.kind' | sort | uniq -c | sort -rn | awk '{printf "  %5d  %s\n", $1, $2}'
else
  echo "  (нет данных)"
fi

echo
bar
echo "Raw logs:    $LOG_DIR"
echo "Daily csv:   jq -r '[.ts[0:10], .project, .input_tokens, .output_tokens] | @csv' $LOG_DIR/stops.jsonl"
