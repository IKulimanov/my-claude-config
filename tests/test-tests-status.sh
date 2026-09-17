#!/usr/bin/env bash
# Тест: tests-status.sh меняет маркер кейса в tests.md; статус changed требует причину и дописывает её
# к строке кейса; неизвестный кейс — ошибка без изменения файла.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/helpers/tests-status.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

CASES="$TMP/tests.md"
cat > "$CASES" <<'EOF'
# Тест-кейсы: пример (ORSP-1)
Статус: согласованы 2026-09-17
Легенда: [ ] не написан · [~] написан, падает (RED) · [x] зелёный · [!] изменён с разрешения (дата, причина)

## Фаза 1. Хранение
- [ ] T1.1 (unit) Дано пусто; когда сохраняем; тогда запись есть.
- [ ] T1.2 (unit) Дано дубль; когда сохраняем; тогда ошибка.
- [ ] T1.10 (unit) Дано десятый; когда; тогда.
EOF

"$SCRIPT" "$CASES" T1.1 red >/dev/null
grep -q '^- \[~\] T1\.1 ' "$CASES" || fail "T1.1 не стал [~]"
grep -q '^- \[ \] T1\.10 ' "$CASES" || fail "T1.10 изменился при правке T1.1"

"$SCRIPT" "$CASES" T1.1 green >/dev/null
grep -q '^- \[x\] T1\.1 ' "$CASES" || fail "T1.1 не стал [x]"

"$SCRIPT" "$CASES" T1.2 changed --reason "поле стало необязательным по решению автора" >/dev/null
grep -qE "^- \[!\] T1\.2 .*\(изменён $(date +%Y-%m-%d): поле стало необязательным по решению автора\)$" "$CASES" || fail "T1.2: нет пометки об изменении"

if "$SCRIPT" "$CASES" T1.10 changed >/dev/null 2>&1; then fail "changed без причины принят"; fi
BEFORE=$(cat "$CASES")
if "$SCRIPT" "$CASES" T9.9 green >/dev/null 2>&1; then fail "неизвестный кейс принят"; fi
[ "$BEFORE" = "$(cat "$CASES")" ] || fail "файл изменён при ошибке"

echo "OK: test-tests-status (маркеры кейсов, changed с причиной, ошибки без изменений)"
