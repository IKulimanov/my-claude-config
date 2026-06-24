#!/usr/bin/env bash
# Тест: вызов инструмента Skill должен фиксировать ИМЯ скилла в input.skill.
# Регрессия: раньше summary tool_input не включал .skill, и аналитика по скиллам
# не могла понять, какой скилл подхватился (значение было "?").

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
export CLAUDE_LOG_DIR="$TMP"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Skill -> input.skill сохранён.
echo '{"hook_event_name":"PreToolUse","tool_name":"Skill","tool_use_id":"t1","session_id":"s","cwd":"/tmp/proj","tool_input":{"skill":"review","args":"src/Foo.java"}}' \
  | bash "$SCRIPT_DIR/../hooks/scripts/log-tool.sh" pre
skill=$(jq -r '.input.skill' "$TMP/tools.jsonl")
[ "$skill" = "review" ] || fail "skill not captured: '$skill'"

# 2. Не-Skill инструмент не должен иметь skill в summary (поле не протекает).
echo '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_use_id":"t2","session_id":"s","cwd":"/tmp/proj","tool_input":{"file_path":"/tmp/proj/x.txt"}}' \
  | bash "$SCRIPT_DIR/../hooks/scripts/log-tool.sh" pre
has=$(jq -rc 'select(.tool=="Read") | .input | has("skill")' "$TMP/tools.jsonl")
[ "$has" = "false" ] || fail "skill leaked into non-Skill summary"

echo "OK: test-log-tool (skill name captured for Skill tool)"
