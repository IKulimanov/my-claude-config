#!/usr/bin/env bash
# Тест: plan-status.sh меняет маркер шага в plan.md, обновляет строку «Обновлён» и дописывает журнал;
# неизвестный шаг и неизвестный статус — ошибка без изменения файла; --summary печатает сводку
# (режимы, счётчики по разделам, вопросы и стоп-точки, следующий шаг) и файл не меняет.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/helpers/plan-status.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

PLAN="$TMP/plan.md"
cat > "$PLAN" <<'EOF'
# План: пример (ORSP-1)
Статус: согласован 2026-09-17 · Обновлён: 2026-09-17 10:00
Тесты: ключевые · Коммиты: после каждой фазы
Легенда: [ ] не начат · [~] в работе · [x] готов · [!] вопрос агента · [#] стоп-точка оператора

## Шаги
### Фаза 1. Хранение
- [x] 1. Миграция — `db/V1.sql`. Проверка: `mvn test`. Кейсы: T1.1
- [ ] 2. Сущность — `Foo.java`. Проверка: `mvn test`. Кейсы: T1.2
### Фаза 2. Чтение
- [#] 3. Кэш — `Cache.java`. Кейсы: T2.1
- [ ] 10. Десятый шаг — `Ten.java`.

## Журнал
- 2026-09-17 10:00 План согласован.
EOF

"$SCRIPT" "$PLAN" 2 wip >/dev/null
grep -q '^- \[~\] 2\. Сущность' "$PLAN" || fail "шаг 2 не стал [~]"
grep -q '^- \[x\] 1\. Миграция' "$PLAN" || fail "шаг 1 изменился"
grep -q '^- \[ \] 10\. Десятый' "$PLAN" || fail "шаг 10 изменился при правке шага 1/2"
grep -qE "^Статус: согласован 2026-09-17 · Обновлён: $(date +%Y-%m-%d) [0-9]{2}:[0-9]{2}$" "$PLAN" || fail "строка «Обновлён» не обновлена"

"$SCRIPT" "$PLAN" 2 done --journal "Фаза 1 готова, 12 тестов зелёные." >/dev/null
grep -q '^- \[x\] 2\. Сущность' "$PLAN" || fail "шаг 2 не стал [x]"
tail -1 "$PLAN" | grep -qE "^- $(date +%Y-%m-%d) [0-9]{2}:[0-9]{2} Фаза 1 готова, 12 тестов зелёные\.$" || fail "журнал не дописан последней строкой"

"$SCRIPT" "$PLAN" 3 ask >/dev/null
grep -q '^- \[!\] 3\. Кэш' "$PLAN" || fail "шаг 3 не стал [!]"
"$SCRIPT" "$PLAN" 3 stop >/dev/null
grep -q '^- \[#\] 3\. Кэш' "$PLAN" || fail "шаг 3 не стал [#]"
"$SCRIPT" "$PLAN" 1 todo >/dev/null
grep -q '^- \[ \] 1\. Миграция' "$PLAN" || fail "шаг 1 не стал [ ]"

BEFORE=$(cat "$PLAN")
if "$SCRIPT" "$PLAN" 42 done >/dev/null 2>&1; then fail "неизвестный шаг принят"; fi
if "$SCRIPT" "$PLAN" 2 bogus >/dev/null 2>&1; then fail "неизвестный статус принят"; fi
[ "$BEFORE" = "$(cat "$PLAN")" ] || fail "файл изменён при ошибке"

# Сводка: шаг 1 [ ], 2 [x], 3 [#], 10 [ ].
BEFORE=$(cat "$PLAN")
OUT=$("$SCRIPT" "$PLAN" --summary)
[ "$BEFORE" = "$(cat "$PLAN")" ] || fail "--summary изменил файл"
printf '%s\n' "$OUT" | grep -qx 'Тесты: ключевые · Коммиты: после каждой фазы' || fail "нет строки режимов"
printf '%s\n' "$OUT" | grep -qx 'Фаза 1. Хранение: 1/2' || fail "нет счётчика фазы 1"
printf '%s\n' "$OUT" | grep -qx 'Фаза 2. Чтение: 0/2' || fail "нет счётчика фазы 2"
printf '%s\n' "$OUT" | grep -q '^- \[#\] 3\. Кэш' || fail "нет стоп-точки"
printf '%s\n' "$OUT" | grep -qx 'Следующий: - \[ \] 1\. Миграция — `db/V1.sql`. Проверка: `mvn test`. Кейсы: T1.1' || fail "нет следующего шага"
printf '%s\n' "$OUT" | grep -q '^Журнал: - .*Фаза 1 готова' || fail "нет последней строки журнала"
[ "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')" -le 12 ] || fail "сводка длиннее 12 строк"

echo "OK: test-plan-status (маркеры шагов, «Обновлён», журнал, ошибки без изменений, --summary)"
