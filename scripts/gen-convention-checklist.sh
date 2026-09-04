#!/usr/bin/env bash
# Генерирует выжимку Sonar-правил конвенции из плагина convention-sonar-rules-plugin.
# Источник правды — HTML-описания правил в плагине (по одному файлу на правило:
# <h2>Why is this an issue?</h2>, Noncompliant / Compliant Code Example).
# Результат — markdown: компактный чек-лист по кодам + детали с примерами.
#
# ВНУТРЕННЕЕ: выжимка содержит командную конвенцию (nurtelecom). Не публиковать
# в открытый доступ (см. пометку в самом выходном файле).
#
# Использование:
#   gen-convention-checklist.sh [--plugin DIR] [--out FILE]
# Без аргументов пишет в skills/java-service-convention/references/sonar-rules.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/skills/java-service-convention/references/sonar-rules.md"

# Путь к репозиторию плагина берём из workspace.conf этой машины; иначе нужен флаг --plugin.
PLUGIN=""
if [ -f "$ROOT/workspace.conf" ]; then
  CONVENTION_PLUGIN=""
  # shellcheck source=/dev/null
  . "$ROOT/workspace.conf"
  PLUGIN="$CONVENTION_PLUGIN"
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --plugin) PLUGIN="$2"; shift 2 ;;
    --out)    OUT="$2"; shift 2 ;;
    -h|--help) grep -E '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$PLUGIN" ]; then
  echo "Не задан путь к репозиторию Sonar-плагина конвенции." >&2
  echo "Пропиши CONVENTION_PLUGIN в workspace.conf или передай --plugin DIR." >&2
  exit 2
fi

RULES_DIR="$PLUGIN/src/main/resources/org/sonar/l10n/java/rules/nurtelecomconventionjavarules"
if [ ! -d "$RULES_DIR" ]; then
  echo "Не найдены описания правил: $RULES_DIR" >&2
  echo "Проверь путь к плагину (--plugin) — скрипт работает только на рабочей машине." >&2
  exit 1
fi

# отсортированный список HTML-файлов правил (bash 3.2 — без mapfile)
FILES=()
while IFS= read -r _line; do
  [ -n "$_line" ] && FILES+=("$_line")
done < <(find "$RULES_DIR" -maxdepth 1 -name '*.html' | sort)
if [ "${#FILES[@]}" -eq 0 ]; then
  echo "В $RULES_DIR нет HTML-описаний правил" >&2
  exit 1
fi

# Парсер одной секции HTML. Аргументы: файл, заголовок-секции, режим (text|code).
# Возвращает текст между <h2>заголовок</h2> и следующим <h2> (или концом файла),
# со снятыми тегами. text — параграфы через пробел; code — как есть построчно.
extract_section() {
  local file="$1" header="$2" mode="$3"
  awk -v hdr="$header" -v mode="$mode" '
    function strip(s){ gsub(/<[^>]*>/,"",s); return s }
    {
      line=$0
      if (line ~ /<h2>/) {
        h=strip(line); gsub(/^[ \t]+|[ \t]+$/,"",h)
        want=(h==hdr); next
      }
      if (!want) next
      t=strip(line)
      if (mode=="code") { print t; next }
      gsub(/^[ \t]+|[ \t]+$/,"",t)
      if (t!="") { buf=(buf==""?t:buf" "t) }
    }
    END { if (mode!="code") print buf }
  ' "$file"
}

first_sentence() {
  # первое предложение (до первой точки). Если длинно — обрезать по ПОСЛЕДНЕМУ пробелу
  # до ~120 байт: граница слова однобайтовая, поэтому кириллица не рвётся на «�».
  # Экранируем '|', чтобы не ломать markdown-таблицу.
  awk '{
    gsub(/\|/,"/")
    n=index($0,".")
    s=(n>0 ? substr($0,1,n) : $0)
    if (length(s) > 120) {
      cut=substr(s,1,120); p=0
      for (i=length(cut); i>0; i--) if (substr(cut,i,1)==" ") { p=i; break }
      s=(p>0 ? substr(cut,1,p-1) : cut) "…"
    }
    print s
  }'
}

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

COUNT="${#FILES[@]}"

{
  echo "# Конвенция: выжимка Sonar-правил (LANG / SPR / DB)"
  echo
  echo "> Сгенерировано \`scripts/gen-convention-checklist.sh\` из \`convention-sonar-rules-plugin\`."
  echo "> **ВНУТРЕННЕЕ — не публиковать** в открытый доступ. Это командная конвенция nurtelecom."
  echo "> Набор совпадает с правилами CI Sonar (\`mvn verify sonar:sonar\`). Правил: $COUNT."
  echo "> Обновить после изменения правил плагина: \`scripts/gen-convention-checklist.sh\`."
  echo
  echo "Как пользоваться: при написании и проверке Java-кода сверяйся по кодам (LANG-/SPR-/DB-)."
  echo "Локальная проверка — предфильтр; финальный вердикт даёт CI Sonar."
  echo
  echo "## Быстрый чек-лист"
  echo
  echo "| Код | Правило |"
  echo "|-----|---------|"
  for f in "${FILES[@]}"; do
    key="$(basename "$f" .html)"
    why="$(extract_section "$f" 'Why is this an issue?' text | first_sentence)"
    echo "| $key | $why |"
  done
  echo
  echo "## Детали с примерами"
  for f in "${FILES[@]}"; do
    key="$(basename "$f" .html)"
    why="$(extract_section "$f" 'Why is this an issue?' text)"
    bad="$(extract_section "$f" 'Noncompliant Code Example' code | sed '/^$/d')"
    good="$(extract_section "$f" 'Compliant Code Example' code | sed '/^$/d')"
    echo
    echo "### $key"
    echo
    [ -n "$why" ] && echo "$why" && echo
    if [ -n "$bad" ]; then
      echo "Неправильно:"
      echo '```java'
      echo "$bad"
      echo '```'
    fi
    if [ -n "$good" ]; then
      echo "Правильно:"
      echo '```java'
      echo "$good"
      echo '```'
    fi
  done
} > "$TMP"

mkdir -p "$(dirname "$OUT")"
mv "$TMP" "$OUT"
trap - EXIT
echo "Записано: $OUT (правил: $COUNT)"
