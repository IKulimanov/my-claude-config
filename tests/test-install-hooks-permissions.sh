#!/usr/bin/env bash
# Тест: install-hooks.sh --write сливает в целевой settings.json секции hooks и permissions.allow/deny/ask
# из hooks/settings.json: свои записи пользователя целы, наши добавлены без дублей, логирующие хуки помечены
# async, ограждения — нет; повторный запуск ничего не меняет.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

TARGET="$TMP/settings.json"
cat > "$TARGET" <<'JSON'
{
  "permissions": {
    "allow": ["Bash(git status*)"],
    "deny": ["Read(**/.env)", "Bash(git push*)"]
  },
  "model": "opus[1m]",
  "hooks": { "Stop": [] }
}
JSON

CLAUDE_SETTINGS_TARGET="$TARGET" "$ROOT/scripts/install-hooks.sh" --write >/dev/null

jq -e '.permissions.allow | index("Bash(git status*)") != null' "$TARGET" >/dev/null || fail "свой allow потерян"
jq -e '.permissions.allow | index("Bash(git diff:*)") != null' "$TARGET" >/dev/null || fail "наш allow не добавлен"
jq -e '.permissions.deny | index("Read(~/.ssh/**)") != null' "$TARGET" >/dev/null || fail "deny на чтение секретов не добавлен"
jq -e '.model == "opus[1m]"' "$TARGET" >/dev/null || fail "прочие ключи потеряны"
jq -e '.permissions.deny | index("Read(**/.env)") != null' "$TARGET" >/dev/null || fail "существующий deny потерян"
jq -e '.permissions.deny | index("Bash(git merge *)") != null' "$TARGET" >/dev/null || fail "наш deny не добавлен"
jq -e '(.permissions.deny | map(select(. == "Bash(git push*)")) | length) == 1' "$TARGET" >/dev/null || fail "дубль в deny"
jq -e '.permissions.ask | index("Edit(**/helm/**)") != null' "$TARGET" >/dev/null || fail "ask не добавлен"
jq -e '.hooks.PreToolUse | length > 0' "$TARGET" >/dev/null || fail "hooks не установлены"
jq -e '[.hooks.PreToolUse[].hooks[].command] | any(test("guard-git.sh"))' "$TARGET" >/dev/null || fail "guard-git.sh не подключён"
jq -e '[.hooks.PreToolUse[].hooks[].command] | any(test("block-push-secrets.sh")) | not' "$TARGET" >/dev/null || fail "block-push-secrets.sh всё ещё подключён"
jq -e '[.hooks[][] | .hooks[] | select(.command | test("log-|notify-stop")) | .async] | length > 0 and all(. == true)' "$TARGET" >/dev/null || fail "логирующие хуки не async"
jq -e '[.hooks.PreToolUse[].hooks[] | select(.command | test("guard-|block-|check-commit")) | .async // false] | all(. == false)' "$TARGET" >/dev/null || fail "ограждение помечено async"

FIRST=$(jq -S . "$TARGET")
CLAUDE_SETTINGS_TARGET="$TARGET" "$ROOT/scripts/install-hooks.sh" --write >/dev/null
SECOND=$(jq -S . "$TARGET")
[ "$FIRST" = "$SECOND" ] || fail "повторный запуск изменил файл"

echo "OK: test-install-hooks-permissions (hooks + deny/ask слиты, allow цел, идемпотентно)"
