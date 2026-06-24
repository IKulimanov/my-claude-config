#!/usr/bin/env bash
# Анализирует ~/.claude/logs/*.jsonl и печатает сводку по использованию Claude.
# Показывает: топ инструментов, топ агентов, топ skills, токены по дням/проектам.
#
# Использование:
#   ./scripts/analyze-usage.sh              # вся история
#   ./scripts/analyze-usage.sh 7            # последние 7 дней
#   ./scripts/analyze-usage.sh 7 my-project # последние 7 дней, только этот проект

set -euo pipefail

LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}"
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

# Helper: фильтр по времени и проекту.
# Логи — строгий JSONL (одна запись на строку, гарантирует hook_log). Читаем
# построчно через -R + fromjson?, чтобы единичная повреждённая строка
# пропускалась, а не роняла весь отчёт.
filter() {
  local file="$1"
  [ ! -f "$file" ] && return
  if [ -n "$PROJECT" ]; then
    jq -cR --arg since "$SINCE" --arg proj "$PROJECT" \
      'fromjson? | select(.ts >= $since and .project == $proj)' "$file"
  else
    jq -cR --arg since "$SINCE" \
      'fromjson? | select(.ts >= $since)' "$file"
  fi
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
filter "$LOG_DIR/prompts.jsonl" | jq -r 'select(.slash_command != null and .slash_command != "") | (.slash_command | split("\n")[0]) | select(test("^/[A-Za-z][A-Za-z0-9_:-]*$"))' | sort | uniq -c | sort -rn | head -15 | awk '{printf "  %5d  %s\n", $1, $2}'

echo
echo "▎Токены"
STOPS_F=$(filter "$LOG_DIR/stops.jsonl")
SUMMARY=$(echo "$STOPS_F" | jq -s '
  {
    sessions: length,
    input_total: (map(.input_tokens) | add // 0),
    output_total: (map(.output_tokens) | add // 0),
    cache_read_total: (map(.cache_read) | add // 0),
    cache_write_total: (map(.cache_write) | add // 0),
    turns_total: (map(.turns) | add // 0)
  }
')
echo "$SUMMARY" | jq -r '
  "  sessions analyzed: \(.sessions)",
  "  input:  \(.input_total) tokens",
  "  output: \(.output_total) tokens",
  "  cache_read:  \(.cache_read_total)",
  "  cache_write: \(.cache_write_total)",
  "  turns total: \(.turns_total)"
'

echo
echo "▎Топ-5 проектов по токенам (input+output)"
echo "$STOPS_F" | jq -s '
  group_by(.project)
  | map({project:.[0].project, tokens: (map(.input_tokens + .output_tokens) | add)})
  | sort_by(-.tokens)
  | .[0:5]
  | .[]
  | "  \(.tokens)\t\(.project)"
' -r | awk -F'\t' '{printf "  %10s  %s\n", $1, $2}'

echo
echo "▎TDD-сигнал (правки/запуски тестов из tools.jsonl)"
# Косвенная проверка iron-law TDD: сколько правок попадает в тест-файлы против
# прод-файлов и как часто реально запускались тесты. Считаем по уже имеющимся
# полям tools.jsonl (file_path / command) — отдельное логирование не нужно.
TDD_F=$(filter "$LOG_DIR/tools.jsonl")
TEST_RE='(Test|Tests)\.java$|_test\.go$|\.(test|spec)\.(ts|js|tsx|jsx)$|/(test|tests|__tests__)/'
RUN_RE='mvn .*test|gradle.*test|gradlew.*test|go test|npm( run)? test|yarn test|pnpm test|vitest|jest|pytest'
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
