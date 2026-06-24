#!/usr/bin/env bash
# Тест устойчивости analyze-usage.sh: одна повреждённая строка в логе не должна
# ронять весь отчёт — её надо пропустить, а валидные записи посчитать.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZE="$SCRIPT_DIR/../scripts/analyze-usage.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# Два валидных SessionStart + одна битая строка посередине.
{
  echo '{"ts":"2026-06-23T10:00:00Z","event":"SessionStart","session":"a","project":"proj-x"}'
  echo '{"ts":"2026-06-23T10:01:00Z" BROKEN not json'
  echo '{"ts":"2026-06-23T10:02:00Z","event":"SessionStart","session":"b","project":"proj-x"}'
} > "$TMP/sessions.jsonl"
# Прочие файлы пустые/минимальные — filter сам обрабатывает отсутствие.
: > "$TMP/stops.jsonl"

export CLAUDE_LOG_DIR="$TMP"
out=$(CLAUDE_LOG_DIR="$TMP" "$ANALYZE" 2>/dev/null) || fail "report aborted on corrupt line (exit $?)"

# Должно посчитать ровно 2 валидных старта, не упав на битой строке.
starts=$(printf '%s\n' "$out" | awk -F': *' '/starts:/{print $2; exit}')
[ "$starts" = "2" ] || fail "expected 2 session starts (corrupt line skipped), got '$starts'"

echo "OK: test-analyze-usage (corrupt line skipped, $starts valid starts counted)"
