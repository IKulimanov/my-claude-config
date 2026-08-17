#!/usr/bin/env bash
# Оркестратор недельной аналитики: сбор снапшота → анализ через headless
# `claude -p` → рендер дашборда → коммит артефактов (только пути analytics/).
# Запускается launchd-джобом по субботам; страховочные срабатывания вс/пн
# безопасны: если отчёт недели уже есть — fast-exit 0.
#
# Гарантия живучести: сбой Claude НИКОГДА не теряет снапшот — вместо отчёта
# пишется стаб со скелетом секций и причиной сбоя, пайплайн завершается с 0.
#
# Использование:
#   run-weekly-review.sh [--week W] [--force] [--skip-analysis] [--skip-commit]
#
# Переопределения (для тестов): CLAUDE_BIN, ANALYTICS_DIR, CLAUDE_LOG_DIR, COLLECT_NOW.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ANALYTICS_DIR="${ANALYTICS_DIR:-$REPO_ROOT/analytics}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
CLAUDE_TIMEOUT_SECONDS=900

WEEK=""
FORCE=0
SKIP_ANALYSIS=0
SKIP_COMMIT=0
CCUSAGE_FLAG="--ccusage"

while [ $# -gt 0 ]; do
  case "$1" in
    --week)          WEEK="$2"; shift 2 ;;
    --force)         FORCE=1; shift ;;
    --skip-analysis) SKIP_ANALYSIS=1; shift ;;
    --skip-commit)   SKIP_COMMIT=1; shift ;;
    --no-ccusage)    CCUSAGE_FLAG=""; shift ;;
    -h|--help) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
done

HISTORY_DIR="$ANALYTICS_DIR/history"
REPORTS_DIR="$ANALYTICS_DIR/reports"
mkdir -p "$HISTORY_DIR" "$REPORTS_DIR"

# --- Lock: защита от параллельных запусков (kickstart + расписание) ---
LOCK_DIR="$ANALYTICS_DIR/.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "Уже выполняется (lock: $LOCK_DIR) — выходим" >&2
  exit 0
fi
WORK=$(mktemp -d)
trap 'rmdir "$LOCK_DIR" 2>/dev/null; rm -rf "$WORK"' EXIT

# --- Целевое окно: date-арифметика живёт в коллекторе ---
if [ -n "$WEEK" ]; then
  read -r PREV_WEEK CUR_WEEK NEXT_WEEK <<<"$("$SCRIPT_DIR/collect-weekly.sh" --print-window --week "$WEEK")"
else
  read -r PREV_WEEK CUR_WEEK NEXT_WEEK <<<"$("$SCRIPT_DIR/collect-weekly.sh" --print-window)"
fi
REPORT_FILE="$REPORTS_DIR/$CUR_WEEK.md"

# Fast-exit: отчёт уже есть, страховочный запуск ничего не делает.
if [ -f "$REPORT_FILE" ] && [ "$FORCE" -ne 1 ]; then
  echo "Отчёт $CUR_WEEK уже есть ($REPORT_FILE) — выходим"
  exit 0
fi

echo "=== Недельная аналитика: $CUR_WEEK (пред. $PREV_WEEK) ==="

# --- 1. Сбор снапшота ---
# shellcheck disable=SC2086  # CCUSAGE_FLAG намеренно без кавычек (пустой = нет флага)
"$SCRIPT_DIR/collect-weekly.sh" --week "$CUR_WEEK" --out "$HISTORY_DIR" $CCUSAGE_FLAG

# --- 2. Анализ через headless claude -p ---
render_stub() { # render_stub <причина>
  local reason="$1"
  {
    echo "# Недельный обзор $CUR_WEEK"
    echo
    echo "## Сводка недели"
    echo "Автоматический анализ не выполнен: $reason."
    echo "Снапшот собран и сохранён — перезапусти: \`scripts/run-weekly-review.sh --force\`."
    echo
    echo "## Динамика vs прошлые недели"
    jq -r '"Сессий: \(.sessions.total) · токены output: \(.tokens.output) · turns: \(.tokens.turns) · активных дней: \(.active_days) · friction: \(.friction.total) · ошибок тулов: \(.tools.failures_total)"' \
      "$HISTORY_DIR/$CUR_WEEK.json" 2>/dev/null || echo "нет данных"
    echo
    echo "## Оценка прошлого эксперимента"
    echo "Не выполнялась (анализ упал)."
    echo
    echo "## Красные флаги"
    echo "Анализ не выполнялся."
    echo
    echo "## Советы по конфигурации"
    echo "Анализ не выполнялся."
    echo
    echo "## Поведенческие рекомендации"
    echo "Анализ не выполнялся."
    echo
    echo "## Эксперимент недели"
    echo "Не задан (анализ упал) — прошлый эксперимент остаётся в силе."
    echo
    echo "## Health report"
    echo "Пайплайн: сбор OK, анализ FAIL ($reason), дашборд см. git-статус."
    echo
    echo "## Данные"
    echo "Снапшот $CUR_WEEK.json (стаб сгенерирован run-weekly-review.sh)."
  } > "$REPORT_FILE"
  echo "Стаб-отчёт записан: $REPORT_FILE (причина: $reason)" >&2
}

analysis_done=0
if [ "$SKIP_ANALYSIS" -eq 1 ]; then
  render_stub "анализ пропущен (--skip-analysis)"
elif ! command -v "$CLAUDE_BIN" >/dev/null 2>&1; then
  render_stub "claude CLI не найден ($CLAUDE_BIN)"
else
  # Подстановка плейсхолдеров промта во временную копию.
  sed -e "s/{{WEEK}}/$CUR_WEEK/g" \
      -e "s/{{PREV_WEEK}}/$PREV_WEEK/g" \
      -e "s/{{NEXT_WEEK}}/$NEXT_WEEK/g" \
      -e "s|{{REPO}}|$REPO_ROOT|g" \
      "$ANALYTICS_DIR/weekly-review-prompt.md" > "$WORK/prompt.md"

  # Portable-таймаут: фоновый запуск + киллер (GNU timeout на macOS нет).
  set +e
  (
    cd "$REPO_ROOT" && \
    "$CLAUDE_BIN" -p "$(cat "$WORK/prompt.md")" \
      --allowedTools "Read,Glob" \
      --model sonnet \
      --output-format text
  ) > "$WORK/report.md" 2>"$WORK/claude.err" &
  claude_pid=$!
  ( sleep "$CLAUDE_TIMEOUT_SECONDS"; kill "$claude_pid" 2>/dev/null ) &
  killer_pid=$!
  wait "$claude_pid"; claude_rc=$?
  kill "$killer_pid" 2>/dev/null
  wait "$killer_pid" 2>/dev/null
  set -e

  # Валидация: отчёт непустой и содержит обязательный скелет.
  if [ "$claude_rc" -eq 0 ] && grep -q '## Сводка недели' "$WORK/report.md" 2>/dev/null; then
    mv "$WORK/report.md" "$REPORT_FILE"
    analysis_done=1
    echo "Отчёт записан: $REPORT_FILE"
  else
    reason="claude exit=$claude_rc"
    [ -s "$WORK/claude.err" ] && reason="$reason, stderr: $(head -c 200 "$WORK/claude.err" | tr '\n' ' ')"
    render_stub "$reason"
  fi
fi

# --- 3. Дашборд ---
"$SCRIPT_DIR/render-dashboard.sh" \
  --history "$HISTORY_DIR" --reports "$REPORTS_DIR" --out "$ANALYTICS_DIR/dashboard.html"

# --- 4. Коммит (только analytics/, никогда не push) ---
if [ "$SKIP_COMMIT" -eq 1 ]; then
  echo "Коммит пропущен (--skip-commit)"
elif [ -z "$(git -C "$REPO_ROOT" status --porcelain -- analytics 2>/dev/null)" ]; then
  echo "Нечего коммитить"
else
  # Pathspec-коммит фиксирует рабочее дерево только этих путей и не подхватывает
  # чужие staged-файлы. Сбой (rebase/merge в процессе) — warning, не fail:
  # файлы на диске, закоммитятся в следующий раз.
  if git -C "$REPO_ROOT" commit -m "analytics: недельный срез $CUR_WEEK" -- analytics >/dev/null 2>&1; then
    echo "Закоммичено: analytics ($CUR_WEEK)"
  else
    echo "ВНИМАНИЕ: git commit не прошёл — артефакты остались в рабочем дереве" >&2
  fi
fi

[ "$analysis_done" -eq 1 ] && echo "=== Готово: $CUR_WEEK ===" || echo "=== Готово (со стабом): $CUR_WEEK ==="
