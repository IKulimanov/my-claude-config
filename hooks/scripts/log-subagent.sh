#!/usr/bin/env bash
# SubagentStart + SubagentStop — пишет вызовы subagent'ов в ~/.claude/logs/subagents.jsonl
# Это главный источник данных «какие агенты я использую и как часто».

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)

EVENT=$(hook_field "$INPUT" '.hook_event_name')
AGENT_TYPE=$(hook_field "$INPUT" '.agent_type' '')
AGENT_ID=$(hook_field "$INPUT" '.agent_id' '')
SESSION=$(hook_field "$INPUT" '.session_id')
CWD=$(hook_field "$INPUT" '.cwd')
PROJECT=$(hook_project_name "$CWD")
EFFORT=$(hook_field "$INPUT" '.effort.level' '')

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg event "$EVENT" \
  --arg agent "$AGENT_TYPE" \
  --arg aid "$AGENT_ID" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  --arg effort "$EFFORT" \
  '{ts:$ts, event:$event, agent_type:$agent, agent_id:$aid, session:$sid, project:$proj, cwd:$cwd, effort:$effort} | with_entries(select(.value != ""))'
)

hook_log "subagents" "$ENTRY"
exit 0
