#!/usr/bin/env bash
# Печатает из выжимки Sonar-правил конвенции только группы, которые касаются изменённых файлов,
# чтобы ревьюер не получал все 30 КБ правил на каждый запуск.
#   LANG — любой Java-файл; SPR — Spring-код (org.springframework или Spring-аннотации);
#   DB — сущности, репозитории, DAO, SQL, миграции.
# Изменённые файлы = дифф ветки от базы + незакоммиченные + новые файлы. Без Java — пустой вывод.
#
#   sonar-rules-for-diff.sh [--base master]
# SONAR_RULES_FILE переопределяет путь к выживке (для тестов).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
RULES="${SONAR_RULES_FILE:-$ROOT_DIR/skills/java-service-convention/references/sonar-rules.md}"
BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    *) echo "Usage: $(basename "$0") [--base <branch>]" >&2; exit 1 ;;
  esac
done

[ -f "$RULES" ] || { echo "Нет выжимки правил: $RULES" >&2; exit 1; }
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Не git-репозиторий" >&2; exit 1; }
cd "$REPO"

if [ -z "$BASE" ]; then
  if git rev-parse --verify -q master >/dev/null; then BASE=master
  elif git rev-parse --verify -q main >/dev/null; then BASE=main
  else BASE=HEAD; fi
fi

FILES=$( { git diff --name-only "$BASE"...HEAD 2>/dev/null || true
           git diff --name-only HEAD 2>/dev/null || true
           git ls-files --others --exclude-standard; } | sort -u | while IFS= read -r f; do [ -f "$f" ] && printf '%s\n' "$f"; done )

JAVA=$(printf '%s\n' "$FILES" | grep -E '\.java$' || true)
[ -n "$JAVA" ] || exit 0

RULE_GROUPS="LANG"
if printf '%s\n' "$JAVA" | xargs grep -lE 'org\.springframework|@(Service|Component|RestController|Controller|Repository|Configuration|Bean|Scheduled|Transactional|Autowired|Value|ConfigurationProperties|KafkaListener)\b' >/dev/null 2>&1; then
  RULE_GROUPS="$RULE_GROUPS,SPR"
fi
if printf '%s\n' "$FILES" | grep -qE '(Entity|Repository|Dao)\.java$|\.sql$|/migration/|/db/' \
   || printf '%s\n' "$JAVA" | xargs grep -lE '@(Entity|Table|Query)\b|jakarta\.persistence|javax\.persistence' >/dev/null 2>&1; then
  RULE_GROUPS="$RULE_GROUPS,DB"
fi

echo "# Правила конвенции для диффа (группы: ${RULE_GROUPS//,/ }; база: $BASE)"
echo
echo "| Код | Правило |"
echo "|-----|---------|"
grep -E "^\| ($(printf '%s' "$RULE_GROUPS" | tr ',' '|'))-" "$RULES" || true
echo
awk -v groups=",$RULE_GROUPS," '
  /^### / { split($2, a, "-"); keep = index(groups, "," a[1] ",") > 0 }
  /^## /  { keep = 0 }
  keep    { print }
' "$RULES"
