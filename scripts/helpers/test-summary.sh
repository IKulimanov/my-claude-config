#!/usr/bin/env bash
# Запускает команду тестов, полный вывод сохраняет в файл, в чат печатает только сводку и упавшие
# тесты: десятки тысяч токенов вывода Maven превращаются в десятки строк. Код возврата команды
# сохраняется.
#
#   test-summary.sh <команда тестов...>
#   test-summary.sh mvn -q test            # Maven (surefire/failsafe)
#   test-summary.sh go test ./...          # Go
#   test-summary.sh npx vitest run         # Vitest / Jest
# TEST_SUMMARY_DIR — куда класть полный вывод (по умолчанию $TMPDIR или /tmp).

set -uo pipefail

[ $# -gt 0 ] || { echo "Usage: $(basename "$0") <test command...>" >&2; exit 1; }

DIR="${TEST_SUMMARY_DIR:-${TMPDIR:-/tmp}}"
DIR="${DIR%/}"
mkdir -p "$DIR"
LOG="$DIR/test-output-$(date +%Y%m%d-%H%M%S)-$$.log"

"$@" > "$LOG" 2>&1
CODE=$?

KEEP='^\[ERROR\]|Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+$|BUILD (SUCCESS|FAILURE)|^--- (FAIL|PASS)|^(FAIL|ok|PASS)([[:space:]]|$)|(Tests|Test Files|Test Suites):|✗|×|^[[:space:]]*[A-Za-z0-9_.$]*(Exception|Error): '
NOISE='Downloading|Downloaded|Progress \(|^\[INFO\] --- |^\[INFO\] Running '

echo "# Полный вывод: $LOG (код возврата $CODE)"
grep -E "$KEEP" "$LOG" | grep -Ev "$NOISE" | awk '!seen[$0]++' | head -80

GO_OK=$(grep -cE '^ok[[:space:]]' "$LOG" || true)
GO_FAIL=$(grep -cE '^(FAIL|--- FAIL)' "$LOG" || true)
if [ "${GO_OK:-0}" -gt 0 ] || [ "${GO_FAIL:-0}" -gt 0 ]; then
  echo "go: ok ${GO_OK:-0}, FAIL ${GO_FAIL:-0}"
fi

exit "$CODE"
