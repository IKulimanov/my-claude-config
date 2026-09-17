#!/usr/bin/env bash
# Меняет маркер кейса в tests.md. Статус changed требует причину и дописывает её к строке кейса.
#
#   tests-status.sh <tests.md> <T1.2> <todo|red|green|changed> [--reason "почему"]
# Статусы: todo [ ] · red [~] написан, падает · green [x] · changed [!] изменён с разрешения.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <tests.md> <T1.2> <todo|red|green|changed> [--reason \"text\"]" >&2
  exit 1
}

[ $# -ge 3 ] || usage
FILE="$1"; ID="$2"; STATUS="$3"; shift 3
REASON=""
while [ $# -gt 0 ]; do
  case "$1" in
    --reason) [ $# -ge 2 ] || usage; REASON="$2"; shift 2 ;;
    *) usage ;;
  esac
done

case "$STATUS" in
  todo)    MARK=' ' ;;
  red)     MARK='~' ;;
  green)   MARK='x' ;;
  changed) MARK='!'; [ -n "$REASON" ] || { echo "Статус changed требует --reason" >&2; exit 1; } ;;
  *) echo "Неизвестный статус: $STATUS (todo|red|green|changed)" >&2; exit 1 ;;
esac

[ -f "$FILE" ] || { echo "Нет файла: $FILE" >&2; exit 1; }
[[ "$ID" =~ ^T[0-9]+\.[0-9]+$ ]] || { echo "Идентификатор кейса вида T1.2: $ID" >&2; exit 1; }
grep -qE "^- \[.\] ${ID//./\\.} " "$FILE" || { echo "Кейс $ID не найден в $FILE" >&2; exit 1; }

SUFFIX=""
[ "$STATUS" = changed ] && SUFFIX=" (изменён $(date +%Y-%m-%d): $REASON)"

ID="$ID" MARK="$MARK" SUFFIX="$SUFFIX" perl -i -pe '
  if (/^- \[.\] \Q$ENV{ID}\E /) { s/^- \[.\] /- [$ENV{MARK}] /; s/\s*$/$ENV{SUFFIX}\n/; }
' "$FILE"

grep -E "^- \[.\] ${ID//./\\.} " "$FILE"
