#!/usr/bin/env bash
# Меняет маркер шага в plan.md, обновляет строку «Обновлён» и по желанию дописывает журнал.
# Правит только маркер и служебные строки — текст плана не трогает, поэтому исполнителю не нужно
# читать и переписывать файл.
#
#   plan-status.sh <plan.md> <номер-шага> <todo|wip|done|ask|stop> [--journal "текст"]
#   plan-status.sh <plan.md> --summary   # сводка без правки файла: строка «Тесты:», счётчики готовых
#                                        # шагов по разделам ###, [!] [#] [~] (до пяти), следующий шаг,
#                                        # последняя строка журнала — оркестратор не читает план целиком
# Статусы: todo [ ] · wip [~] · done [x] · ask [!] вопрос агента · stop [#] стоп-точка оператора.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <plan.md> <step> <todo|wip|done|ask|stop> [--journal \"text\"] | <plan.md> --summary" >&2
  exit 1
}

if [ $# -eq 2 ] && [ "$2" = "--summary" ]; then
  [ -f "$1" ] || { echo "Нет файла: $1" >&2; exit 1; }
  perl -CSD -Mutf8 -ne '
    chomp;
    if (/^Тесты:/) { print "$_\n"; next }
    if (/^## /) { $in_steps = /^## Шаги/; $in_journal = /^## Журнал/; next }
    if ($in_journal && /^- /) { $journal = $_; next }
    next unless $in_steps;
    if (/^### (.+)$/) { push @sec, $1; $total{$1} = 0; $done{$1} = 0; next }
    if (/^- \[(.)\] \d+\. /) {
      my $m = $1; my $sec = @sec ? $sec[-1] : "Шаги";
      push @sec, $sec unless exists $total{$sec};
      $total{$sec}++; $done{$sec}++ if $m eq "x";
      push @flag, $_ if $m =~ /[!#~]/;
      $next //= $_ if $m eq " ";
    }
    END {
      print "$_: $done{$_}/$total{$_}\n" for @sec;
      print "$_\n" for @flag[0 .. ($#flag < 4 ? $#flag : 4)];
      print "Следующий: $next\n" if defined $next;
      print "Журнал: $journal\n" if defined $journal;
    }
  ' "$1"
  exit 0
fi

[ $# -ge 3 ] || usage
PLAN="$1"; STEP="$2"; STATUS="$3"; shift 3
JOURNAL=""
while [ $# -gt 0 ]; do
  case "$1" in
    --journal) [ $# -ge 2 ] || usage; JOURNAL="$2"; shift 2 ;;
    *) usage ;;
  esac
done

case "$STATUS" in
  todo) MARK=' ' ;;
  wip)  MARK='~' ;;
  done) MARK='x' ;;
  ask)  MARK='!' ;;
  stop) MARK='#' ;;
  *) echo "Неизвестный статус: $STATUS (todo|wip|done|ask|stop)" >&2; exit 1 ;;
esac

[ -f "$PLAN" ] || { echo "Нет файла: $PLAN" >&2; exit 1; }
[[ "$STEP" =~ ^[0-9]+$ ]] || { echo "Номер шага — число: $STEP" >&2; exit 1; }
grep -qE "^- \[.\] ${STEP}\. " "$PLAN" || { echo "Шаг $STEP не найден в $PLAN" >&2; exit 1; }

NOW=$(date '+%Y-%m-%d %H:%M')
STEP="$STEP" MARK="$MARK" NOW="$NOW" perl -i -pe '
  s/^- \[.\] \Q$ENV{STEP}\E\. /- [$ENV{MARK}] $ENV{STEP}. /;
  s/(Обновлён: )\d{4}-\d{2}-\d{2} \d{2}:\d{2}/$1$ENV{NOW}/;
' "$PLAN"

if [ -n "$JOURNAL" ]; then
  ENTRY="- $NOW $JOURNAL"
  # Вставить последней строкой секции «Журнал» (перед следующим заголовком второго уровня или в конец).
  # Кириллица не доходит до awk через ENV на macOS, поэтому позиции считаем по номерам строк,
  # а текст вставляет perl.
  START=$(grep -n '^## Журнал' "$PLAN" | head -1 | cut -d: -f1 || true)
  if [ -z "$START" ]; then
    printf '\n## Журнал\n%s\n' "$ENTRY" >> "$PLAN"
  else
    NEXT=$(awk -v s="$START" 'NR > s && /^## / { print NR; exit }' "$PLAN")
    if [ -z "$NEXT" ]; then
      printf '%s\n' "$ENTRY" >> "$PLAN"
    else
      # Перед следующим заголовком обычно стоит пустая строка: вставляем перед ней, иначе добавляем свою.
      INS="$NEXT"; SEP=$'\n\n'
      if [ -z "$(sed -n "$((NEXT - 1))p" "$PLAN")" ]; then INS=$((NEXT - 1)); SEP=$'\n'; fi
      INS="$INS" ENTRY="$ENTRY" SEP="$SEP" perl -i -pe 'print "$ENV{ENTRY}$ENV{SEP}" if $. == $ENV{INS}' "$PLAN"
    fi
  fi
fi

grep -E "^- \[.\] ${STEP}\. " "$PLAN"
