#!/usr/bin/env bash
# Локальный прогон «нашего Sonar» на Community Build: рабочее дерево анализируется в песочный проект
# <ключ>-local (в основной проект с локальной машины анализ не идёт — это перезаписало бы состояние
# master на сервере), затем issues по изменённым файлам печатаются в формате MQR: собственные правила
# команды первыми, встроенные — по серьёзности.
#
#   sonar-local.sh [--init] [--all] [--base <ветка>] [--no-analyze] [--report-task <файл>] [--out <файл>] [--dry-run]
#   --init         создать песочный проект, поставить тег sandbox, привязать профиль основного проекта
#   --all          все issues проекта, а не только по изменённым файлам
#   --no-analyze   не запускать сканер, только дождаться задачи из --report-task и забрать issues
#   --dry-run      показать ключи и команды, ничего не запускать
# Окружение: SONAR_HOST_URL, SONAR_TOKEN (обязательно); SONAR_PROJECT_KEY — ключ основного проекта
# (иначе из sonar-project.properties или kg.nurtelecom:<artifactId>); SONAR_MVN — команда сканера
# (по умолчанию mvn -q -DskipTests compile sonar:sonar); SONAR_KEY_PREFIX — префикс ключа (kg.nurtelecom).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/sonar-lib.sh"

INIT=0; ALL=0; BASE=""; ANALYZE=1; REPORT_TASK=""; OUT=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --init) INIT=1; shift ;;
    --all) ALL=1; shift ;;
    --base) BASE="$2"; shift 2 ;;
    --no-analyze) ANALYZE=0; shift ;;
    --report-task) REPORT_TASK="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "Usage: $(basename "$0") [--init] [--all] [--base <branch>] [--no-analyze] [--report-task <file>] [--out <file>] [--dry-run]" >&2; exit 1 ;;
  esac
done

[ "$DRY" = 1 ] || sonar_require_env
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "Не git-репозиторий" >&2; exit 1; }
cd "$REPO"

# Ключ основного проекта и песочницы
KEY="${SONAR_PROJECT_KEY:-}"
if [ -z "$KEY" ] && [ -f sonar-project.properties ]; then
  KEY=$(grep -E '^sonar\.projectKey=' sonar-project.properties | head -1 | cut -d= -f2- | tr -d '[:space:]')
fi
if [ -z "$KEY" ] && [ -f pom.xml ]; then
  ARTIFACT=$(sed -e '/<parent>/,/<\/parent>/d' pom.xml | grep -m1 -oE '<artifactId>[^<]+' | sed 's/<artifactId>//')
  [ -n "$ARTIFACT" ] && KEY="${SONAR_KEY_PREFIX:-kg.nurtelecom}:$ARTIFACT"
fi
[ -n "$KEY" ] || KEY="${SONAR_KEY_PREFIX:-kg.nurtelecom}:$(basename "$REPO")"
KEY_LOCAL="${KEY}-local"

if [ -z "$BASE" ]; then
  if git rev-parse --verify -q master >/dev/null; then BASE=master
  elif git rev-parse --verify -q main >/dev/null; then BASE=main
  else BASE=HEAD; fi
fi

MVN="${SONAR_MVN:-mvn -q -DskipTests compile sonar:sonar}"
SCAN_CMD="$MVN -Dsonar.projectKey=$KEY_LOCAL -Dsonar.projectName=$KEY_LOCAL -Dsonar.host.url=\$SONAR_HOST_URL -Dsonar.token=\$SONAR_TOKEN"

if [ "$DRY" = 1 ]; then
  echo "проект: $KEY"
  echo "песочница: $KEY_LOCAL"
  echo "база диффа: $BASE"
  echo "команда анализа: $SCAN_CMD"
  [ "$INIT" = 1 ] && echo "init: api/projects/create, api/project_tags/set (sandbox), api/qualityprofiles/add_project (профиль проекта $KEY)"
  exit 0
fi

if [ "$INIT" = 1 ]; then
  EXISTS=$(sonar_get "api/projects/search?projects=$KEY_LOCAL" | jq -r '.components | length')
  if [ "$EXISTS" = "0" ]; then
    sonar_post "api/projects/create" "project=$KEY_LOCAL&name=$KEY_LOCAL" >/dev/null && echo "создан проект $KEY_LOCAL"
  else
    echo "проект $KEY_LOCAL уже есть"
  fi
  sonar_post "api/project_tags/set" "project=$KEY_LOCAL&tags=sandbox" >/dev/null && echo "тег sandbox поставлен"
  PROFILE=$(sonar_get "api/qualityprofiles/search?project=$KEY" | jq -r '.profiles[] | select(.language == "java") | .name' | head -1)
  if [ -n "$PROFILE" ]; then
    sonar_post "api/qualityprofiles/add_project" "language=java&qualityProfile=$PROFILE&project=$KEY_LOCAL" >/dev/null \
      && echo "профиль «$PROFILE» привязан к $KEY_LOCAL"
  else
    echo "профиль Java основного проекта не найден — назначь профиль конвенции песочнице вручную" >&2
  fi
fi

if [ "$ANALYZE" = 1 ]; then
  echo "анализ $KEY_LOCAL: $MVN" >&2
  eval "$MVN" -Dsonar.projectKey="$KEY_LOCAL" -Dsonar.projectName="$KEY_LOCAL" -Dsonar.host.url="$SONAR_HOST_URL" -Dsonar.token="$SONAR_TOKEN" >&2
  [ -n "$REPORT_TASK" ] || REPORT_TASK=$(find . -path '*/target/sonar/report-task.txt' -newer pom.xml 2>/dev/null | head -1)
  [ -n "$REPORT_TASK" ] || REPORT_TASK=$(find . -path '*/target/sonar/report-task.txt' 2>/dev/null | head -1)
fi

[ -n "$REPORT_TASK" ] && [ -f "$REPORT_TASK" ] || { echo "Нет report-task.txt: анализ не прошёл или укажи --report-task" >&2; exit 1; }
TASK_ID=$(grep -E '^ceTaskId=' "$REPORT_TASK" | cut -d= -f2-)
[ -n "$TASK_ID" ] || { echo "В $REPORT_TASK нет ceTaskId" >&2; exit 1; }

# Ждём, пока сервер обработает отчёт
for _ in $(seq 1 120); do
  STATUS=$(sonar_get "api/ce/task?id=$TASK_ID" | jq -r '.task.status')
  case "$STATUS" in
    SUCCESS) break ;;
    FAILED|CANCELED) echo "Задача $TASK_ID завершилась со статусом $STATUS" >&2; exit 1 ;;
    *) sleep 5 ;;
  esac
done
[ "${STATUS:-}" = SUCCESS ] || { echo "Задача $TASK_ID не завершилась за отведённое время" >&2; exit 1; }

ISSUES=$(sonar_fetch_issues "$KEY_LOCAL")
FILTER=""
[ "$ALL" = 1 ] || FILTER=$(sonar_changed_files_json "$BASE")
REPORT=$(sonar_format_report "$ISSUES" "$KEY_LOCAL" "$FILTER")
if [ -n "$OUT" ]; then
  printf '%s\n' "$REPORT" > "$OUT"
  echo "отчёт: $OUT"
fi
printf '%s\n' "$REPORT"
