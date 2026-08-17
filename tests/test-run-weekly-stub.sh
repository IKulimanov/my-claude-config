#!/usr/bin/env bash
# Тест пути сбоя run-weekly-review.sh: headless Claude недоступен
# (CLAUDE_BIN=/nonexistent) — пайплайн ОБЯЗАН выжить:
#  - снапшот собран, отчёт-стаб записан (со скелетом секций и причиной);
#  - дашборд отрендерен; exit 0;
#  - повторный запуск без --force — fast-exit, отчёт не перезаписан.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER="$SCRIPT_DIR/../scripts/run-weekly-review.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

LOGS="$TMP/logs"; ADIR="$TMP/analytics"
mkdir -p "$LOGS"

# Минимальные фикстуры в окне 2026-W22 (Сб 2026-05-23 → Пт 2026-05-29).
echo '{"ts":"2026-05-25T08:00:00Z","event":"SessionStart","session":"s1","project":"p"}' > "$LOGS/sessions.jsonl"
echo '{"ts":"2026-05-25T10:00:00Z","phase":"pre","tool":"Bash","tool_use_id":"t1","project":"p","input":{"command":"ls"}}' > "$LOGS/tools.jsonl"
: > "$LOGS/prompts.jsonl"
: > "$LOGS/stops.jsonl"
: > "$LOGS/subagents.jsonl"
: > "$LOGS/blocks.jsonl"

run_runner() {
  CLAUDE_LOG_DIR="$LOGS" COLLECT_NOW="2026-06-01T09:00:00Z" \
  CLAUDE_BIN=/nonexistent ANALYTICS_DIR="$ADIR" \
  "$RUNNER" --skip-commit --no-ccusage "$@"
}

run_runner || fail "runner упал (exit $?) — путь сбоя должен давать exit 0"

REPORT="$ADIR/reports/2026-W22.md"
[ -f "$ADIR/history/2026-W22.json" ] || fail "снапшот не собран"
[ -f "$REPORT" ] || fail "отчёт-стаб не записан"
grep -q '## Сводка недели' "$REPORT" || fail "в стабе нет скелета секций"
grep -q 'Автоматический анализ не выполнен' "$REPORT" || fail "в стабе нет причины"
[ -f "$ADIR/dashboard.html" ] || fail "дашборд не отрендерен"
grep -q '2026-W22' "$ADIR/dashboard.html" || fail "в дашборде нет недели"

# Повторный запуск: fast-exit, отчёт не перезаписан.
echo "MARKER-SENTINEL" >> "$REPORT"
run_runner || fail "повторный запуск упал"
grep -q 'MARKER-SENTINEL' "$REPORT" || fail "fast-exit не сработал: отчёт перезаписан"

# --force: пересобирает и перезаписывает стаб.
run_runner --force || fail "--force упал"
grep -q 'MARKER-SENTINEL' "$REPORT" && fail "--force не перезаписал отчёт"

echo "OK: test-run-weekly-stub (стаб-отчёт, fast-exit, --force)"
