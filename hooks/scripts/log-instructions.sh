#!/usr/bin/env bash
# InstructionsLoaded — фиксирует загрузку CLAUDE.md / rules / памяти проекта.
# ВНИМАНИЕ: это НЕ источник по skills. Skills подхватываются через инструмент
# Skill и видны в tools.jsonl (tool=="Skill", input.skill). Здесь — только память.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)

FILE_PATH=$(hook_field "$INPUT" '.file_path' '')
MEMORY_TYPE=$(hook_field "$INPUT" '.memory_type' '')
LOAD_REASON=$(hook_field "$INPUT" '.load_reason' '')
SESSION=$(hook_field "$INPUT" '.session_id')
CWD=$(hook_field "$INPUT" '.cwd')
PROJECT=$(hook_project_name "$CWD")

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg fp "$FILE_PATH" \
  --arg mtype "$MEMORY_TYPE" \
  --arg lr "$LOAD_REASON" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  '{ts:$ts, file_path:$fp, memory_type:$mtype, load_reason:$lr, session:$sid, project:$proj, cwd:$cwd} | with_entries(select(.value != ""))'
)

hook_log "instructions" "$ENTRY"
exit 0
