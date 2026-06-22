#!/usr/bin/env bash
# InstructionsLoaded — фиксирует загрузку CLAUDE.md / rules / skills.
# Главный источник данных «какие skills реально подхватываются».

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

# Попытка вычленить имя skill из пути (skills/<name>/SKILL.md → <name>)
SKILL=""
if [[ "$FILE_PATH" =~ skills/([^/]+)/ ]]; then
  SKILL="${BASH_REMATCH[1]}"
fi

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg fp "$FILE_PATH" \
  --arg mtype "$MEMORY_TYPE" \
  --arg lr "$LOAD_REASON" \
  --arg skill "$SKILL" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  '{ts:$ts, file_path:$fp, memory_type:$mtype, load_reason:$lr, skill:$skill, session:$sid, project:$proj, cwd:$cwd} | with_entries(select(.value != ""))'
)

hook_log "instructions" "$ENTRY"
exit 0
