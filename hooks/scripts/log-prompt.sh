#!/usr/bin/env bash
# UserPromptSubmit — фиксирует факт промпта (длина, slash-command если есть)
# БЕЗ полного текста промпта — приватность важнее. Если хочешь полный — снимай комментарий.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)

PROMPT=$(hook_field "$INPUT" '.prompt' '')
SESSION=$(hook_field "$INPUT" '.session_id')
CWD=$(hook_field "$INPUT" '.cwd')
PROJECT=$(hook_project_name "$CWD")

LEN=${#PROMPT}
# slash-команда (если есть) — только ведущий /token первой строки.
SLASH=$(hook_slash_command "$PROMPT")

# Превью промпта для анализа (первые 500 символов).
# Используем bash-параметры вместо tr/head, чтобы не падать на UTF-8 (кириллица и пр.).
HEAD="${PROMPT//$'\n'/ }"
HEAD="${HEAD:0:500}"

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  --argjson len "$LEN" \
  --arg slash "$SLASH" \
  --arg head "$HEAD" \
  '{ts:$ts, session:$sid, project:$proj, cwd:$cwd, length:$len, slash_command:$slash, head:$head} | with_entries(select(.value != "" and .value != null))'
)

hook_log "prompts" "$ENTRY"
exit 0
