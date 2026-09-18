#!/usr/bin/env bash
# Список файлов, в которые исполнитель задачи имеет право писать: <каталог задачи>/agent/scope.txt.
# Первая строка — статус (`# scope: active` или `# scope: done`), дальше по строке на файл или маску
# относительно корня репозитория: `*` захватывает и `/` (src/test/java/kg/* — весь подкаталог), строка
# с `/` на конце — каталог целиком. Пока статус active, хук guard-scope.sh спрашивает подтверждение
# на запись вне списка.
#
#   scope.sh <каталог задачи> add <путь|маска>…   # создать файл при нужде, дописать без дублей
#   scope.sh <каталог задачи> done | active       # выключить или включить проверку
#   scope.sh <каталог задачи> check <путь>        # 0 — писать можно (в списке, файла нет, done); 1 — вне списка

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <task-dir> add <pattern>... | done | active | check <path>" >&2
  exit 1
}
[ $# -ge 2 ] || usage
DIR="$1"; CMD="$2"; shift 2
FILE="$DIR/agent/scope.txt"

set_status() {   # <active|done>
  mkdir -p "$DIR/agent"
  [ -f "$FILE" ] || printf '# scope: %s\n' "$1" > "$FILE"
  if head -1 "$FILE" | grep -q '^# scope:'; then
    STATUS="$1" perl -i -pe 's/^# scope: .*/# scope: $ENV{STATUS}/ if $. == 1' "$FILE"
  else
    STATUS="$1" perl -i -pe 'print "# scope: $ENV{STATUS}\n" if $. == 1' "$FILE"
  fi
}

case "$CMD" in
  add)
    [ $# -ge 1 ] || usage
    mkdir -p "$DIR/agent"
    [ -f "$FILE" ] || printf '# scope: active\n' > "$FILE"
    for p in "$@"; do
      p="${p#./}"
      [ -n "$p" ] || continue
      grep -qxF -- "$p" "$FILE" || printf '%s\n' "$p" >> "$FILE"
    done
    echo "scope: $(grep -vc '^#' "$FILE" || true) строк, $(head -1 "$FILE")"
    ;;
  done|active)
    set_status "$CMD"
    head -1 "$FILE"
    ;;
  check)
    [ $# -eq 1 ] || usage
    [ -f "$FILE" ] || exit 0
    head -1 "$FILE" | grep -q '^# scope: done' && exit 0
    rel="${1#./}"
    while IFS= read -r pat || [ -n "$pat" ]; do
      pat="${pat%$'\r'}"
      case "$pat" in ''|'#'*) continue ;; esac
      pat="${pat#./}"
      if [[ "$pat" == */ ]]; then
        [[ "$rel" == "$pat"* ]] && exit 0
      else
        [[ "$rel" == $pat ]] && exit 0
      fi
    done < "$FILE"
    exit 1
    ;;
  *) usage ;;
esac
