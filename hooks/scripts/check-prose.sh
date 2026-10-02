#!/usr/bin/env bash
# PostToolUse / Edit|Write|MultiEdit - текст для людей (правило 07, "Любой текст"): символы не с клавиатуры
# и фразы-штампы в .md, .html, .txt. Смотрим только добавленный текст (content, new_string), а не файл целиком:
# иначе каждая правка старого документа давала бы предупреждение за чужие строки.
# Запись уже состоялась и не отменяется: хук возвращает additionalContext, агент исправляет сам.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')
case "$TOOL" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac

TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
case "$TARGET" in *.md|*.markdown|*.html|*.htm|*.txt) ;; *) exit 0 ;; esac
# Файлы, где запрещённое стоит намеренно: чужие скилы, примеры воды, данные хуков, фикстуры, выгрузка Sonar.
case "$TARGET" in
  */skills/synced/*|*/skills/writing/references/*|*/hooks/data/*|*/tests/*|*/sonar-rules.md) exit 0 ;;
esac

TEXT=$(printf '%s' "$INPUT" | jq -r '.tool_input | [.content, .new_string, (.edits // [] | .[].new_string)] | map(select(. != null)) | join("\n")')
[ -z "$TEXT" ] && exit 0

STAMPS="${PROSE_STAMPS_FILE:-$SCRIPT_DIR/../data/prose-stamps.txt}"
case "$TARGET" in *.html|*.htm) IS_HTML=1 ;; *) IS_HTML=0 ;; esac

# Печатает находки по одной в строке: "символ <знак> - <чем заменить>" или "штамп <фраза>".
FOUND=$(printf '%s' "$TEXT" | IS_HTML="$IS_HTML" STAMPS="$STAMPS" perl -Mutf8 -CSD -0777 -e '
  my $t = <STDIN>;
  if ($ENV{IS_HTML}) { $t =~ s{<(style|script|code|pre)\b.*?</\1\s*>}{ }gis; }
  $t =~ s/^[ \t]*(```|~~~).*?^[ \t]*\1[^\n]*$/ /gms;
  $t =~ s/`[^`\n]*`/ /g;
  my @chars = (
    ["\x{2192}", "->"], ["\x{2190}", "<-"], ["\x{21D2}", "=>"], ["\x{2194}", "<->"],
    ["\x{2014}", "дефис - или перестроить предложение"], ["\x{2013}", "дефис -"],
    ["\x{AB}", "прямая кавычка \""], ["\x{BB}", "прямая кавычка \""],
    ["\x{201C}", "прямая кавычка \""], ["\x{201D}", "прямая кавычка \""], ["\x{201E}", "прямая кавычка \""],
    ["\x{2019}", "апостроф \x27"], ["\x{2026}", "три точки ..."], ["\x{2022}", "дефис -"], ["\x{B7}", "запятая или |"],
    ["\x{2713}", "[x]"], ["\x{2714}", "[x]"], ["\x{2717}", "[ ]"], ["\x{2718}", "[ ]"],
    ["\x{2264}", "<="], ["\x{2265}", ">="], ["\x{2260}", "!="], ["\x{D7}", "x"],
  );
  for my $c (@chars) { print "символ $c->[0] - $c->[1]\n" if index($t, $c->[0]) >= 0; }
  print "символ неразрывный пробел - обычный пробел\n" if $t =~ /[\x{A0}\x{202F}\x{2009}]/;
  print "символ нулевой ширины - удалить\n" if $t =~ /[\x{200B}\x{200C}\x{200D}\x{FEFF}]/;
  if (open(my $fh, "<", $ENV{STAMPS})) {
    my $low = lc $t;
    local $/ = "\n";
    while (my $p = <$fh>) {
      chomp $p; next if $p =~ /^\s*(#|$)/;
      print "штамп $p\n" if index($low, lc $p) >= 0;
    }
  }
')
[ -z "$FOUND" ] && exit 0

CHARS=$(printf '%s\n' "$FOUND" | sed -n 's/^символ //p' | paste -sd ';' - | sed 's/;/; /g')
PHRASES=$(printf '%s\n' "$FOUND" | sed -n 's/^штамп //p' | paste -sd ';' - | sed 's/;/"; "/g')
MSG="check-prose: в тексте, добавленном в $TARGET, есть то, что правило 07 (\"Любой текст\") просит не писать."
[ -n "$CHARS" ] && MSG="$MSG Символы и замены: $CHARS."
[ -n "$PHRASES" ] && MSG="$MSG Фразы-штампы: \"$PHRASES\" - убери или замени фактом."
MSG="$MSG Исправь эти места сейчас. Цитату чужого текста и код можно оставить."

hook_context "$MSG"
CWD=$(hook_field "$INPUT" '.cwd')
hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg tgt "$TARGET" \
  --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" \
  --arg found "$(printf '%s' "$FOUND" | paste -sd ';' - | head -c 300)" \
  '{ts:$ts, kind:"prose", decision:"warn", tool:$tool, session:$sid, project:$proj, cwd:$cwd, target:$tgt, reason:$found}')"
exit 0
