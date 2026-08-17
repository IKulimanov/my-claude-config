#!/usr/bin/env bash
# Тест: block-хуки пишут поле project в blocks.jsonl (basename cwd).
# Без него project-фильтр аналитики молча теряет все блокировки.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$SCRIPT_DIR/../hooks/scripts"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

export CLAUDE_LOG_DIR="$TMP"

# 1. block-destructive: rm -rf блокируется, запись содержит project.
echo '{"tool_input":{"command":"rm -rf /tmp/x"},"session_id":"s1","cwd":"/Users/ivan/dev/proj-alpha"}' \
  | "$HOOKS/block-destructive.sh" >/dev/null
[ -f "$TMP/blocks.jsonl" ] || fail "destructive: blocks.jsonl не создан"
[ "$(jq -r '.project' "$TMP/blocks.jsonl")" = "proj-alpha" ] || fail "destructive: нет project"
[ "$(jq -r '.kind' "$TMP/blocks.jsonl")" = "destructive" ] || fail "destructive: kind"

# 2. block-secrets: чтение .env блокируется, запись содержит project.
: > "$TMP/blocks.jsonl"
echo '{"tool_name":"Read","tool_input":{"file_path":"/Users/ivan/dev/proj-beta/.env"},"session_id":"s2","cwd":"/Users/ivan/dev/proj-beta"}' \
  | "$HOOKS/block-secrets.sh" >/dev/null
[ "$(jq -r '.project' "$TMP/blocks.jsonl")" = "proj-beta" ] || fail "secrets: нет project"
[ "$(jq -r '.kind' "$TMP/blocks.jsonl")" = "secret" ] || fail "secrets: kind"

echo "OK: test-block-project (project пишется в blocks.jsonl)"
