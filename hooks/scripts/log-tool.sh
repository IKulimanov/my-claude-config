#!/usr/bin/env bash
# PreToolUse + PostToolUse / * — пишет каждый tool call в ~/.claude/logs/tools.jsonl
# Фиксирует: какой инструмент, какой агент его вызвал (если subagent), параметры (без секретов).
# Для PreToolUse — фаза "pre", для PostToolUse — "post" с длительностью.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
PHASE="${1:-pre}"  # передаём через argv: pre | post | fail

EVENT=$(hook_field "$INPUT" '.hook_event_name')
TOOL=$(hook_field "$INPUT" '.tool_name')
TOOL_ID=$(hook_field "$INPUT" '.tool_use_id')
SESSION=$(hook_field "$INPUT" '.session_id')
CWD=$(hook_field "$INPUT" '.cwd')
PROJECT=$(hook_project_name "$CWD")
AGENT=$(hook_field "$INPUT" '.agent_type' '')

# Краткое описание input — обрезаем длинные/чувствительные поля
INPUT_SUMMARY=$(echo "$INPUT" | jq -c '
  .tool_input
  | if type == "object" then
      {
        file_path: .file_path,
        pattern: .pattern,
        url: .url,
        command: (.command // "" | .[0:200]),
        description: .description,
        subagent_type: .subagent_type,
        skill: .skill,
        args: (.args // "" | .[0:120]),
        prompt: (.prompt // "" | .[0:120])
      }
      | with_entries(select(.value != null and .value != ""))
    else . end
')

# Для PostToolUse — попробуем достать размер result. На pre — 0.
RESULT_SIZE=$(echo "$INPUT" | jq -r '(.tool_result // null) | if . == null then 0 else (tostring | length) end')

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg phase "$PHASE" \
  --arg event "$EVENT" \
  --arg tool "$TOOL" \
  --arg tid "$TOOL_ID" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  --arg agent "$AGENT" \
  --argjson inp "$INPUT_SUMMARY" \
  --argjson rsz "$RESULT_SIZE" \
  '{ts:$ts, phase:$phase, event:$event, tool:$tool, tool_use_id:$tid, session:$sid, project:$proj, cwd:$cwd, agent:$agent, input:$inp, result_size:$rsz}'
)

hook_log "tools" "$ENTRY"
exit 0
