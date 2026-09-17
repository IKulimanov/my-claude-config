#!/usr/bin/env bash
# Тест: sonar-local.sh (без анализа), sonar-issues.sh и sonar-rule.sh против поддельного сервера Sonar
# (python http.server с JSON-ответами): ожидание задачи CE, выборка issues в формате MQR, фильтр по диффу,
# собственные правила первыми, описание правила.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPERS="$SCRIPT_DIR/../scripts/helpers"
TMP=$(mktemp -d)
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- поддельный сервер ---------------------------------------------------------------------------
FIX="$TMP/fixtures"
mkdir -p "$FIX/api/issues" "$FIX/api/ce" "$FIX/api/rules"
cat > "$FIX/api/ce/task" <<'JSON'
{"task":{"id":"AZtask1","status":"SUCCESS","componentKey":"kg.nurtelecom:demo-local"}}
JSON
cat > "$FIX/api/issues/search" <<'JSON'
{"total":3,"p":1,"ps":500,"paging":{"pageIndex":1,"pageSize":500,"total":3},"issues":[
 {"key":"i1","rule":"java:S1192","component":"kg.nurtelecom:demo-local:src/main/java/kg/demo/Foo.java","line":12,
  "message":"Define a constant instead of duplicating this literal","impacts":[{"softwareQuality":"MAINTAINABILITY","severity":"LOW"}],"status":"OPEN"},
 {"key":"i2","rule":"nurtelecomconventionjavarules:LANG-410","component":"kg.nurtelecom:demo-local:src/main/java/kg/demo/Foo.java","line":30,
  "message":"Метод длиннее 30 строк","impacts":[{"softwareQuality":"MAINTAINABILITY","severity":"HIGH"}],"status":"OPEN"},
 {"key":"i3","rule":"java:S2259","component":"kg.nurtelecom:demo-local:src/main/java/kg/demo/Bar.java","line":7,
  "message":"A NullPointerException could be thrown","impacts":[{"softwareQuality":"RELIABILITY","severity":"BLOCKER"}],"status":"OPEN"}
]}
JSON
cat > "$FIX/api/rules/show" <<'JSON'
{"rule":{"key":"nurtelecomconventionjavarules:LANG-410","name":"Метод не длиннее 30 строк","htmlDesc":"<p>Метод должен быть <b>короче</b> 30 строк.</p>","impacts":[{"softwareQuality":"MAINTAINABILITY","severity":"HIGH"}]}}
JSON
printf 'projectKey=kg.nurtelecom:demo-local\nceTaskId=AZtask1\nceTaskUrl=http://x/api/ce/task?id=AZtask1\n' > "$TMP/report-task.txt"

PORT=$(( 18000 + RANDOM % 1000 ))
( cd "$FIX" && python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 ) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null; rm -rf "$TMP"' EXIT
for _ in $(seq 1 30); do curl -s "http://127.0.0.1:$PORT/api/ce/task" >/dev/null 2>&1 && break; sleep 0.2; done

export SONAR_HOST_URL="http://127.0.0.1:$PORT"
export SONAR_TOKEN="test-token"
export SONAR_PROJECT_KEY="kg.nurtelecom:demo"

# --- репозиторий с диффом: Foo.java изменён, Bar.java нет -------------------------------------------
REPO="$TMP/repo"
git init -q -b master "$REPO"
mkdir -p "$REPO/src/main/java/kg/demo"
echo "class Foo {}" > "$REPO/src/main/java/kg/demo/Foo.java"
echo "class Bar {}" > "$REPO/src/main/java/kg/demo/Bar.java"
git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m init
git -C "$REPO" checkout -q -b feature/x
echo "class Foo { int x; }" > "$REPO/src/main/java/kg/demo/Foo.java"

# --- sonar-local.sh без анализа ------------------------------------------------------------------
OUT=$(cd "$REPO" && "$HELPERS/sonar-local.sh" --no-analyze --report-task "$TMP/report-task.txt")
echo "$OUT" | grep -q 'LANG-410' || fail "нет собственного правила в отчёте"
echo "$OUT" | grep -q 'S1192' || fail "нет встроенного правила по изменённому файлу"
echo "$OUT" | grep -q 'S2259' && fail "issue по неизменённому файлу попал в отчёт без --all"
OWN_LINE=$(echo "$OUT" | grep -n 'LANG-410' | head -1 | cut -d: -f1)
BUILTIN_LINE=$(echo "$OUT" | grep -n 'S1192' | head -1 | cut -d: -f1)
[ "$OWN_LINE" -lt "$BUILTIN_LINE" ] || fail "собственные правила должны идти первыми"
echo "$OUT" | grep -q 'Foo.java:30' || fail "нет файла и строки"
echo "$OUT" | grep -q 'HIGH' || fail "нет серьёзности MQR"
echo "$OUT" | grep -qE 'kg\.nurtelecom:demo-local' || fail "нет ключа песочницы в отчёте"

OUT_ALL=$(cd "$REPO" && "$HELPERS/sonar-local.sh" --no-analyze --all --report-task "$TMP/report-task.txt")
echo "$OUT_ALL" | grep -q 'S2259' || fail "с --all нет issue по неизменённому файлу"

# --- sonar-issues.sh ------------------------------------------------------------------------------
OUT_I=$("$HELPERS/sonar-issues.sh" kg.nurtelecom:demo-local)
echo "$OUT_I" | grep -q 'S2259' || fail "sonar-issues: нет issue"
echo "$OUT_I" | grep -q 'BLOCKER' || fail "sonar-issues: нет серьёзности"
[ "$(echo "$OUT_I" | grep -c '·')" -ge 3 ] || fail "sonar-issues: ожидались три строки issue"

# --- sonar-rule.sh --------------------------------------------------------------------------------
OUT_R=$("$HELPERS/sonar-rule.sh" nurtelecomconventionjavarules:LANG-410)
echo "$OUT_R" | grep -q 'Метод не длиннее 30 строк' || fail "sonar-rule: нет названия"
echo "$OUT_R" | grep -q 'короче' || fail "sonar-rule: нет описания"
echo "$OUT_R" | grep -q '<b>' && fail "sonar-rule: HTML-теги не убраны"

# --- без переменных окружения — понятная ошибка ---------------------------------------------------
if (unset SONAR_HOST_URL; "$HELPERS/sonar-issues.sh" kg.nurtelecom:demo-local >/dev/null 2>&1); then
  fail "без SONAR_HOST_URL должна быть ошибка"
fi

echo "OK: test-sonar-scripts (ожидание CE, выборка MQR, фильтр по диффу, порядок правил, описание правила)"
