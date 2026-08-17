#!/usr/bin/env bash
# Тесты секций отчёта analyze-usage.sh на фикстурах:
#  - skills: считаются из Skill-вызовов в tools.jsonl (а не из мёртвого .skill);
#  - slash: многострочное (старое, повреждённое) значение не «протекает» в "at"/"<td";
#  - TDD-сигнал: правки тест-файлов и запуски тестов считаются из tools.jsonl.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZE="$SCRIPT_DIR/../scripts/analyze-usage.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- tools.jsonl: Skill-вызовы, правки тест/прод-файлов, запуски тестов ---
{
  echo '{"ts":"2026-06-23T10:00:00Z","phase":"pre","tool":"Skill","project":"p","input":{"skill":"review"}}'
  echo '{"ts":"2026-06-23T10:00:01Z","phase":"pre","tool":"Skill","project":"p","input":{"skill":"plan"}}'
  echo '{"ts":"2026-06-23T10:00:02Z","phase":"pre","tool":"Edit","project":"p","input":{"file_path":"/p/src/test/java/FooTest.java"}}'
  echo '{"ts":"2026-06-23T10:00:03Z","phase":"pre","tool":"Write","project":"p","input":{"file_path":"/p/bar_test.go"}}'
  echo '{"ts":"2026-06-23T10:00:04Z","phase":"pre","tool":"Edit","project":"p","input":{"file_path":"/p/src/main/App.java"}}'
  echo '{"ts":"2026-06-23T10:00:05Z","phase":"pre","tool":"Bash","project":"p","input":{"command":"mvn -q test"}}'
  echo '{"ts":"2026-06-23T10:00:06Z","phase":"pre","tool":"Bash","project":"p","input":{"command":"go test ./..."}}'
  echo '{"ts":"2026-06-23T10:00:07Z","phase":"pre","tool":"Bash","project":"p","input":{"command":"ls -la"}}'
} > "$TMP/tools.jsonl"

# --- prompts.jsonl: один чистый slash + один старый многострочный (повреждённый) ---
{
  echo '{"ts":"2026-06-23T10:00:00Z","project":"p","slash_command":"/review"}'
  printf '%s\n' '{"ts":"2026-06-23T10:00:01Z","project":"p","slash_command":"/feature\nat the top\n<td>x</td>"}'
  echo '{"ts":"2026-06-23T10:00:02Z","project":"p","slash_command":"/Users/ivan/Downloads/raw.txt"}'
} > "$TMP/prompts.jsonl"

# --- минимальные прочие файлы ---
echo '{"ts":"2026-06-23T10:00:00Z","event":"SessionStart","project":"p"}' > "$TMP/sessions.jsonl"
# Стопы КУМУЛЯТИВНЫ в рамках сессии: сумма сессии = последняя строка, а не сумма строк.
{
  echo '{"ts":"2026-06-23T10:00:00Z","session":"s1","project":"p","input_tokens":10,"output_tokens":20,"cache_read":0,"cache_write":0,"turns":2}'
  echo '{"ts":"2026-06-23T11:00:00Z","session":"s1","project":"p","input_tokens":30,"output_tokens":50,"cache_read":0,"cache_write":0,"turns":5}'
} > "$TMP/stops.jsonl"

out=$(CLAUDE_LOG_DIR="$TMP" "$ANALYZE" 2>/dev/null) || fail "report aborted (exit $?)"

# 1. skills: review и plan должны быть в отчёте.
printf '%s\n' "$out" | grep -qE '[0-9]+  review$' || fail "skills: 'review' missing"
printf '%s\n' "$out" | grep -qE '[0-9]+  plan$'   || fail "skills: 'plan' missing"

# 2. slash: чистые команды есть, мусор от многострочного значения отсутствует.
printf '%s\n' "$out" | grep -qE '[0-9]+  /review$'  || fail "slash: '/review' missing"
printf '%s\n' "$out" | grep -qE '[0-9]+  /feature$' || fail "slash: '/feature' missing"
printf '%s\n' "$out" | grep -qE '[0-9]+  at$' && fail "slash: noise 'at' leaked"
printf '%s\n' "$out" | grep -q '<td'              && fail "slash: noise '<td' leaked"
printf '%s\n' "$out" | grep -q '/Users/'          && fail "slash: path leaked as command"

# 3. Токены: кумулятивные стопы не пересуммируются — сессия = последняя строка.
printf '%s\n' "$out" | grep -qE 'input:[[:space:]]+30 tokens'  || fail "tokens: input != 30 (кумулятив пересуммирован?)"
printf '%s\n' "$out" | grep -qE 'output:[[:space:]]+50 tokens' || fail "tokens: output != 50"
printf '%s\n' "$out" | grep -qE 'sessions analyzed:[[:space:]]+1' || fail "tokens: sessions != 1"

# 4. TDD-сигнал: 2 правки тестов, 1 правка прод, 2 запуска тестов.
printf '%s\n' "$out" | grep -qE 'тест-файл[а-я]*:[[:space:]]+2'  || fail "tdd: test edits != 2"
printf '%s\n' "$out" | grep -qE 'прод-файл[а-я]*:[[:space:]]+1'  || fail "tdd: prod edits != 1"
printf '%s\n' "$out" | grep -qE 'запуск[а-я]* тест[а-я]*:[[:space:]]+2' || fail "tdd: test runs != 2"

echo "OK: test-analyze-sections (skills + slash-defensive + tdd-signal)"
