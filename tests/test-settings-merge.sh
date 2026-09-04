#!/usr/bin/env bash
# Проверка merge-логики install-hooks.sh: свои permissions пользователя не теряются,
# hooks перезаписываются, повторный запуск идемпотентен.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
W=$(mktemp -d)
export HOME="$W"
mkdir -p "$W/.claude"

# Существующие настройки пользователя: свой allow, своя настройка, старые хуки.
cat > "$W/.claude/settings.json" <<'JSON'
{
  "agentPushNotifEnabled": true,
  "outputStyle": "personal",
  "permissions": { "allow": ["Bash(mvn test:*)"], "deny": ["Read(~/secret.txt)"] },
  "hooks": { "Stop": [{ "matcher": "*", "hooks": [{ "type": "command", "command": "/old/path.sh" }] }] }
}
JSON

"$ROOT/scripts/install-hooks.sh" --write >/dev/null
cp "$W/.claude/settings.json" "$W/after1.json"
"$ROOT/scripts/install-hooks.sh" --write >/dev/null
cp "$W/.claude/settings.json" "$W/after2.json"

S="$W/.claude/settings.json"
ok=0; bad=0
t() { if [ "$2" = "$3" ]; then printf '  OK     %s\n' "$1"; ok=$((ok+1)); else printf '  ПРОВАЛ %s: ждали "%s", получили "%s"\n' "$1" "$3" "$2"; bad=$((bad+1)); fi; }

t "свой allow сохранён"        "$(jq -r '.permissions.allow | index("Bash(mvn test:*)") != null' "$S")" "true"
t "свой deny сохранён"         "$(jq -r '.permissions.deny  | index("Read(~/secret.txt)") != null' "$S")" "true"
t "наш allow добавлен"         "$(jq -r '.permissions.allow | index("Bash(git status:*)") != null' "$S")" "true"
t "наш deny добавлен"          "$(jq -r '.permissions.deny  | index("Read(~/.ssh/**)") != null' "$S")" "true"
t "чужие ключи не тронуты"     "$(jq -r '.outputStyle' "$S")" "personal"
t "cleanupPeriodDays выставлен" "$(jq -r '.cleanupPeriodDays' "$S")" "90"
t "старый хук вытеснен"        "$(jq -r '[.. | strings | select(. == "/old/path.sh")] | length' "$S")" "0"
t "async проставлен"           "$(jq -r '.hooks.PostToolUse[0].hooks[0].async' "$S")" "true"
t "блокирующие хуки синхронны" "$(jq -r '.hooks.PreToolUse[0].hooks[0].async // "нет"' "$S")" "нет"
t "путь развёрнут"             "$(jq -r '.hooks.PostToolUse[0].hooks[0].command | startswith("/Users/ivan/my-claude-config")' "$S")" "true"
t "идемпотентность"            "$(cmp -s "$W/after1.json" "$W/after2.json" && echo same || echo diff)" "same"
t "нет дублей в allow"         "$(jq -r '.permissions.allow | (length == (unique | length))' "$S")" "true"

echo
echo "Итого: $ok пройдено, $bad провалено"
rm -rf "$W"
[ "$bad" -eq 0 ]
