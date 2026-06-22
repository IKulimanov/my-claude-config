#!/usr/bin/env bash
# PreToolUse / Bash — блокирует destructive команды.
# Регексы покрывают типовые случаи; bypass через хитрую quoting возможен —
# полагаемся не только на этот хук, но и на allowlist в settings.json.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
CMD=$(hook_field "$INPUT" '.tool_input.command' '')

if [ -z "$CMD" ]; then
  exit 0
fi

PATTERN='(\brm[[:space:]]+([^|;&]*[[:space:]])?-[a-zA-Z]*r[a-zA-Z]*f|\brm[[:space:]]+([^|;&]*[[:space:]])?-[a-zA-Z]*f[a-zA-Z]*r|git[[:space:]]+push[[:space:]]+([^|;&]*--force|[^|;&]*-f([[:space:]]|$))[^|;&]*(main|master|staging|prod|production)|\bDROP[[:space:]]+TABLE\b|\bDROP[[:space:]]+DATABASE\b|\bTRUNCATE[[:space:]]+TABLE\b|\bchmod[[:space:]]+777\b|\bmkfs\.|:>/dev/sd)'

if echo "$CMD" | grep -qiE "$PATTERN"; then
  hook_deny "Blocked: destructive pattern detected. Run manually if intended. Command: $(echo "$CMD" | head -c 200)"
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg cmd "$CMD" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$(hook_field "$INPUT" '.cwd')" '{ts:$ts, kind:"destructive", session:$sid, cwd:$cwd, command:$cmd}')"
  exit 0
fi

exit 0
