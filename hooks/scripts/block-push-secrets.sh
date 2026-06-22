#!/usr/bin/env bash
# PreToolUse / Bash — перед `git push` запускает trufflehog (если установлен)
# и блокирует push при найденных секретах.
# Если trufflehog не установлен — молча пропускает (warning в stderr).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
CMD=$(hook_field "$INPUT" '.tool_input.command' '')

if [ -z "$CMD" ]; then
  exit 0
fi

if [[ ! "$CMD" =~ ^[[:space:]]*git[[:space:]]+push ]]; then
  exit 0
fi

CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")

if ! command -v trufflehog >/dev/null 2>&1; then
  echo "[hook] trufflehog not installed — secret scan skipped." >&2
  exit 0
fi

SCAN_OUT=$(trufflehog filesystem --no-update --no-verification --json "$CWD" 2>/dev/null || true)

if [ -n "$SCAN_OUT" ]; then
  COUNT=$(echo "$SCAN_OUT" | wc -l | tr -d ' ')
  hook_deny "Blocked: trufflehog found $COUNT potential secret(s). Inspect and clean before push."
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg n "$COUNT" '{ts:$ts, kind:"push-secrets", session:$sid, cwd:$cwd, found:($n|tonumber)}')"
  exit 0
fi

exit 0
