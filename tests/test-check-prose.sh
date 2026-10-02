#!/usr/bin/env bash
# Тест: check-prose.sh (PostToolUse) предупреждает о символах не с клавиатуры и фразах-штампах в тексте,
# который агент добавил в .md, .html, .txt. Смотрит только добавленный текст (content, new_string),
# пропускает код, пути-исключения и прочие типы файлов. Запись не блокирует: ответ - additionalContext.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/check-prose.sh"
[ -x "$HOOK" ] || fail "хука нет или он не исполняемый: $HOOK"

ARROW=$'\xe2\x86\x92'; DASH=$'\xe2\x80\x94'; LQ=$'\xc2\xab'; RQ=$'\xc2\xbb'; DOTS=$'\xe2\x80\xa6'; NBSP=$'\xc2\xa0'
ctx() { hook_context "$HOOK" "$1" "$TMP" "$2" "$3"; }
has() { case "$1" in *"$2"*) ;; *) fail "$3: в ответе нет '$2': $1" ;; esac; }
silent() { [ -z "$1" ] || fail "$2: ожидалась тишина, получено: $1"; }

# T1: стрелка в Write - названы символ, замена и файл
OUT=$(ctx Write "$TMP/notes.md" "данные $ARROW сервис")
has "$OUT" "$ARROW" T1; has "$OUT" "->" T1; has "$OUT" "notes.md" T1

# T2: тире, ёлочки, многоточие, неразрывный пробел - все в одном ответе
OUT=$(ctx Write "$TMP/notes.md" "Хук $DASH это ${LQ}проверка${RQ}$DOTS и${NBSP}всё")
has "$OUT" "$DASH" T2; has "$OUT" "$LQ" T2; has "$OUT" "$DOTS" T2; has "$OUT" "неразрывный пробел" T2

# T3: Edit с чистым new_string - тишина, даже если в файле на диске есть тире; MultiEdit проверяется так же
printf 'старая строка %s с тире\n' "$DASH" > "$TMP/old.md"
silent "$(ctx Edit "$TMP/old.md" "новая чистая строка")" T3
OUT=$(ctx MultiEdit "$TMP/old.md" "строка $ARROW")
has "$OUT" "$ARROW" "T3 MultiEdit"

# T4: символ в блоке кода и в inline code - тишина
silent "$(ctx Write "$TMP/code.md" $'Пример:\n```\na '"$ARROW"$' b\n```\nи `x '"$DASH"' y` в строке')" T4

# T5: не текстовые файлы - тишина
for f in A.java run.sh data.json; do silent "$(ctx Write "$TMP/$f" "a $ARROW b $DASH c")" "T5 $f"; done

# T6: фраза-штамп, регистр не важен
OUT=$(ctx Write "$TMP/doc.md" "Важно отметить, что хук работает.")
has "$OUT" "важно отметить" T6

# T7: пути-исключения
for f in skills/synced/x/SKILL.md skills/writing/references/slop-patterns.md hooks/data/list.txt tests/fixture.md \
         skills/java-service-convention/references/sonar-rules.md; do
  silent "$(ctx Write "$TMP/$f" "a $ARROW b, важно отметить")" "T7 $f"
done

# T8: html - текст проверяется, style и script нет
silent "$(ctx Write "$TMP/r.html" "<style>a::before{content:'$ARROW'}</style><script>var s='$DASH';</script><p>чисто</p>")" "T8 style/script"
OUT=$(ctx Write "$TMP/r.html" "<p>шаг $ARROW шаг</p>")
has "$OUT" "$ARROW" T8

# T9: чистый текст - тишина и нет записи в журнале; находка - запись kind prose
rm -f "$CLAUDE_LOG_DIR/blocks.jsonl"
silent "$(ctx Write "$TMP/clean.md" $'# Заголовок\n\nОбычный текст - с дефисом, "кавычками" и -> стрелкой.\n- [ ] пункт')" T9
[ ! -s "$CLAUDE_LOG_DIR/blocks.jsonl" ] || fail "T9: запись в blocks.jsonl без находки"
ctx Write "$TMP/notes.md" "a $ARROW b" >/dev/null
grep -q '"kind":"prose"' "$CLAUDE_LOG_DIR/blocks.jsonl" || fail "T9: нет записи kind prose"

echo "OK: test-check-prose (символы и штампы в добавленном тексте - предупреждение; код, исключения, чистый текст - тишина)"
