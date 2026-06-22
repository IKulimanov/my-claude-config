#!/usr/bin/env bash
# SessionStart + SessionEnd — пишет начало/конец сессии в ~/.claude/logs/sessions.jsonl

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)

EVENT=$(hook_field "$INPUT" '.hook_event_name')
SESSION=$(hook_field "$INPUT" '.session_id')
CWD=$(hook_field "$INPUT" '.cwd')
PROJECT=$(hook_project_name "$CWD")
MODEL=$(hook_field "$INPUT" '.model' '')
SOURCE=$(hook_field "$INPUT" '.source' '')
REASON=$(hook_field "$INPUT" '.reason' '')

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg event "$EVENT" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  --arg model "$MODEL" \
  --arg source "$SOURCE" \
  --arg reason "$REASON" \
  '{ts:$ts, event:$event, session:$sid, project:$proj, cwd:$cwd, model:$model, source:$source, reason:$reason} | with_entries(select(.value != ""))'
)

hook_log "sessions" "$ENTRY"
exit 0
