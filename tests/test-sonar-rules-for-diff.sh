#!/usr/bin/env bash
# Тест: sonar-rules-for-diff.sh печатает из выжимки только правила тех групп, которые касаются
# изменённых файлов: LANG — для любого Java, SPR — если есть Spring-код, DB — если задеты сущности,
# репозитории, SQL или миграции; без Java-файлов — пусто и код 0.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/helpers/sonar-rules-for-diff.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

RULES="$TMP/rules.md"
cat > "$RULES" <<'EOF'
# Конвенция: выжимка Sonar-правил (LANG / SPR / DB)

## Быстрый чек-лист

| Код | Правило |
|-----|---------|
| DB-002 | Названия таблиц во множественном числе. |
| LANG-103 | Имя класса совпадает с именем файла. |
| SPR-902 | Параметризованное логирование. |

## Детали с примерами

### LANG-103
Текст правила LANG-103.

### SPR-902
Текст правила SPR-902.

### DB-002
Текст правила DB-002.
EOF
export SONAR_RULES_FILE="$RULES"

REPO="$TMP/repo"
git init -q -b master "$REPO"
mkdir -p "$REPO/src/main/java/kg/demo" "$REPO/src/main/resources/db/migration"
echo "class Base {}" > "$REPO/src/main/java/kg/demo/Base.java"
git -C "$REPO" add -A && git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m init
git -C "$REPO" checkout -q -b feature/x

# 1. Только чистый Java-класс → LANG, без SPR и DB
echo "class Util {}" > "$REPO/src/main/java/kg/demo/Util.java"
OUT=$(cd "$REPO" && "$SCRIPT")
echo "$OUT" | grep -q 'LANG-103' || fail "нет LANG для Java-файла"
echo "$OUT" | grep -q 'SPR-902' && fail "SPR без Spring-кода"
echo "$OUT" | grep -q 'DB-002' && fail "DB без сущностей"

# 2. Spring-сервис → LANG + SPR
printf 'import org.springframework.stereotype.Service;\n@Service class Svc {}\n' > "$REPO/src/main/java/kg/demo/Svc.java"
OUT=$(cd "$REPO" && "$SCRIPT")
echo "$OUT" | grep -q 'SPR-902' || fail "нет SPR для Spring-кода"

# 3. Миграция → DB
echo "create table foos (id int);" > "$REPO/src/main/resources/db/migration/V1__foos.sql"
OUT=$(cd "$REPO" && "$SCRIPT")
echo "$OUT" | grep -q 'DB-002' || fail "нет DB для миграции"
echo "$OUT" | grep -q 'Текст правила DB-002' || fail "нет текста правила DB-002"

# 4. Без Java-файлов → пусто
rm "$REPO/src/main/java/kg/demo/Util.java" "$REPO/src/main/java/kg/demo/Svc.java" "$REPO/src/main/resources/db/migration/V1__foos.sql"
echo "# doc" > "$REPO/README.md"
OUT=$(cd "$REPO" && "$SCRIPT")
[ -z "$OUT" ] || fail "ожидался пустой вывод без Java-файлов, получено: $OUT"

echo "OK: test-sonar-rules-for-diff (LANG/SPR/DB по составу диффа, пусто без Java)"
