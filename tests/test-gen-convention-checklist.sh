#!/usr/bin/env bash
# Тест генератора выжимки Sonar-правил конвенции.
# Проверяет: парсинг HTML-описаний правил из плагина → markdown-выжимка
# (компактная таблица + детали с примерами + внутренний заголовок).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/scripts/gen-convention-checklist.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- фикстура: мини-плагин с двумя правилами ---
RULES_DIR="$TMP/plugin/src/main/resources/org/sonar/l10n/java/rules/nurtelecomconventionjavarules"
mkdir -p "$RULES_DIR"

cat > "$RULES_DIR/LANG-410.html" <<'HTML'
<h2>Why is this an issue?</h2>
<p>Максимальное количество параметров метода, к которому нужно стремиться — 3.</p>
<p>В остальных случаях используйте модель-обёртку.</p>
<h2>Noncompliant Code Example</h2>
<pre>
void pay(String a, BigDecimal b, String c, LocalDate d, String e) {}
</pre>
<h2>Compliant Code Example</h2>
<pre>
void pay(PaymentRequest request) {}
</pre>
HTML

cat > "$RULES_DIR/SPR-902.html" <<'HTML'
<h2>Why is this an issue?</h2>
<p>Не используйте конкатенацию строк в логах SLF4J.</p>
<h2>Noncompliant Code Example</h2>
<pre>
log.info("User " + id);
</pre>
<h2>Compliant Code Example</h2>
<pre>
log.info("User {}", id);
</pre>
HTML

OUT="$TMP/sonar-rules.md"
bash "$GEN" --plugin "$TMP/plugin" --out "$OUT" >/dev/null 2>&1 || fail "генератор завершился с ошибкой"

[ -f "$OUT" ] || fail "выходной файл не создан"

# оба кода правил присутствуют
grep -q 'LANG-410' "$OUT" || fail "нет кода LANG-410"
grep -q 'SPR-902'  "$OUT" || fail "нет кода SPR-902"

# компактная таблица (чек-лист по кодам)
grep -qE '^\| *Код' "$OUT" || fail "нет заголовка таблицы чек-листа"

# текст правила из <p> попал в выжимку
grep -q 'параметров метода' "$OUT" || fail "нет текста правила LANG-410"
grep -q 'конкатенац'         "$OUT" || fail "нет текста правила SPR-902"

# примеры кода (правильно/неправильно) попали в детали
grep -q 'PaymentRequest' "$OUT" || fail "нет compliant-примера LANG-410"
grep -q 'log.info("User {}"' "$OUT" || fail "нет compliant-примера SPR-902"

# внутренний маркер (не публиковать)
grep -qiE 'внутрен|не публик' "$OUT" || fail "нет пометки про внутреннее использование"

# счётчик правил = 2
grep -qE 'Правил.*2|2 .*правил' "$OUT" || fail "нет корректного счётчика правил"

# пустой плагин → ненулевой код выхода
if bash "$GEN" --plugin "$TMP/empty" --out "$TMP/x.md" >/dev/null 2>&1; then
  fail "пустой плагин должен давать ошибку"
fi

echo "OK: test-gen-convention-checklist"
