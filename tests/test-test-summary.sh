#!/usr/bin/env bash
# Тест: test-summary.sh запускает команду тестов, печатает только сводку и упавшие тесты,
# сохраняет код возврата; полный вывод кладёт в файл, путь к которому печатает.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/helpers/test-summary.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Имитация вывода Maven с одним упавшим тестом
cat > "$TMP/mvn.txt" <<'EOF'
[INFO] Scanning for projects...
[INFO] --- surefire:3.2.5:test (default-test) @ demo ---
[INFO] Running kg.demo.FooTest
[INFO] Tests run: 3, Failures: 0, Errors: 0, Skipped: 0, Time elapsed: 0.1 s -- in kg.demo.FooTest
[INFO] Running kg.demo.BarTest
[ERROR] Tests run: 2, Failures: 1, Errors: 0, Skipped: 0, Time elapsed: 0.2 s <<< FAILURE! -- in kg.demo.BarTest
[ERROR] kg.demo.BarTest.shouldFail -- Time elapsed: 0.01 s <<< FAILURE!
org.opentest4j.AssertionFailedError: expected: <1> but was: <2>
	at kg.demo.BarTest.shouldFail(BarTest.java:12)
[INFO] Downloading from central: https://repo.maven.apache.org/x
[INFO] Results:
[ERROR] Failures:
[ERROR]   BarTest.shouldFail:12 expected: <1> but was: <2>
[ERROR] Tests run: 5, Failures: 1, Errors: 0, Skipped: 0
[INFO] BUILD FAILURE
[INFO] Total time:  12.3 s
EOF

set +e
OUT=$("$SCRIPT" bash -c "cat '$TMP/mvn.txt'; exit 1" 2>/dev/null)
CODE=$?
set -e
[ "$CODE" -eq 1 ] || fail "код возврата не сохранён: $CODE"
echo "$OUT" | grep -q 'Tests run: 5, Failures: 1' || fail "нет итоговой строки"
echo "$OUT" | grep -q 'BarTest.shouldFail' || fail "нет упавшего теста"
echo "$OUT" | grep -q 'BUILD FAILURE' || fail "нет статуса сборки"
echo "$OUT" | grep -q 'Downloading from central' && fail "шум попал в сводку"
echo "$OUT" | grep -q 'Scanning for projects' && fail "шум попал в сводку"
LOG=$(echo "$OUT" | grep -oE '/[^ ]*test-output[^ ]*\.log' | head -1)
[ -n "$LOG" ] && [ -f "$LOG" ] || fail "полный вывод не сохранён в файл"
grep -q 'Scanning for projects' "$LOG" || fail "в файле нет полного вывода"

# Успешный прогон Go
OUT2=$("$SCRIPT" bash -c "printf 'ok  \tkg/demo/pkg\t0.012s\nok  \tkg/demo/api\t0.020s\n'; exit 0")
echo "$OUT2" | grep -qE 'ok.*2' || fail "нет сводки для go test"

echo "OK: test-test-summary (сводка Maven и Go, код возврата, полный вывод в файле)"
