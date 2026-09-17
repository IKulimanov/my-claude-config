#!/usr/bin/env bash
# Тест: design-init.sh создаёт каркас docs/projects/<проект>/ из шаблонов плейбука,
# не перезаписывает существующие файлы, поддерживает --dry-run и проверяет имя проекта.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
SCRIPT="$ROOT/scripts/helpers/design-init.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Корень проектов переопределяется для теста, шаблоны берутся из репозитория.
export DESIGN_PROJECTS_ROOT="$TMP/projects"

# 1. dry-run ничего не создаёт
"$SCRIPT" --dry-run business-demo-manager >/dev/null
[ ! -d "$TMP/projects/business-demo-manager" ] || fail "dry-run создал каталог"

# 2. создание каркаса
OUT=$("$SCRIPT" business-demo-manager)
DIR="$TMP/projects/business-demo-manager"
[ "$OUT" = "$DIR" ] || fail "скрипт должен печатать путь каталога, получено: $OUT"
for f in 00-brief.md 01-design.md 02-plan.md; do [ -f "$DIR/$f" ] || fail "нет $f"; done
for d in adr options assets; do [ -d "$DIR/$d" ] || fail "нет каталога $d"; done
grep -q 'business-demo-manager' "$DIR/00-brief.md" || fail "имя проекта не подставлено в brief"
grep -q "$(date +%Y-%m-%d)" "$DIR/00-brief.md" || fail "дата не подставлена в brief"
grep -q '{{' "$DIR/00-brief.md" && fail "в brief остались плейсхолдеры"
grep -q '{{' "$DIR/01-design.md" && fail "в design остались плейсхолдеры"

# 3. повторный запуск не перезаписывает
echo "правка" >> "$DIR/00-brief.md"
"$SCRIPT" business-demo-manager >/dev/null
grep -q 'правка' "$DIR/00-brief.md" || fail "повторный запуск перезаписал brief"

# 4. плохое имя отклоняется
if "$SCRIPT" "Bad Name" >/dev/null 2>&1; then fail "имя с пробелом принято"; fi
if "$SCRIPT" >/dev/null 2>&1; then fail "пустое имя принято"; fi

echo "OK: test-design-init (каркас, подстановка, идемпотентность, dry-run, валидация имени)"
