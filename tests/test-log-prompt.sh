#!/usr/bin/env bash
# Тесты извлечения slash-команды из промпта.
# Регрессия: awk '{print $1}' на многострочном промпте печатал первый токен
# КАЖДОЙ строки, и значение slash_command «протекало» в "at", "<td", "|".
# Должны брать только ведущий /command первой строки и ничего больше.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export CLAUDE_LOG_DIR="$TMP"
. "$SCRIPT_DIR/../hooks/scripts/lib/common.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Простая команда без аргументов.
[ "$(hook_slash_command '/review')" = "/review" ] || fail "plain command"

# 2. Команда с аргументами — только первый токен.
[ "$(hook_slash_command '/plan сделай рефакторинг')" = "/plan" ] || fail "command with args"

# 3. Многострочный промпт — значение не должно «протекать» в следующие строки.
ML=$'/feature добавь X\nat the top\n<td>cell</td>\n| a | b |'
got=$(hook_slash_command "$ML")
[ "$got" = "/feature" ] || fail "multiline leaked: got '$got'"
case "$got" in *$'\n'*) fail "newline leaked into slash_command";; esac

# 4. Не-команда -> пусто.
[ -z "$(hook_slash_command 'обычный промпт без слеша')" ] || fail "non-command should be empty"

# 4a. Абсолютный путь в начале промпта — это НЕ команда.
[ -z "$(hook_slash_command '/Users/ivan/Downloads/raw.txt посмотри')" ] || fail "path misread as command"
[ -z "$(hook_slash_command '/usr/bin/env bash script.sh')" ] || fail "shebang path misread as command"

# 4b. Namespaced команда плагина — сохраняется целиком.
[ "$(hook_slash_command '/cowork:create-plugin аргумент')" = "/cowork:create-plugin" ] || fail "namespaced command lost"

# 5. Интеграция: хук log-prompt.sh пишет ровно один чистый slash_command.
echo '{"prompt":"/review\nat the top\n<td>x</td>","session_id":"s1","cwd":"/tmp/proj-x"}' \
  | bash "$SCRIPT_DIR/../hooks/scripts/log-prompt.sh"
slash=$(jq -r '.slash_command' "$TMP/prompts.jsonl")
[ "$slash" = "/review" ] || fail "hook wrote wrong slash_command: '$slash'"
lines=$(wc -l < "$TMP/prompts.jsonl" | tr -d ' ')
[ "$lines" -eq 1 ] || fail "expected 1 record, got $lines"

echo "OK: test-log-prompt (slash extraction, no multiline leak)"
