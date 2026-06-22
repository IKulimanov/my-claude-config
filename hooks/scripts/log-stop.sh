#!/usr/bin/env bash
# Stop — фиксирует конец тёрна и суммирует токены из transcript.
# Парсит transcript_path (jsonl) и складывает usage по каждому assistant message.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)

# Анти-петля: если Stop hook сам себя триггерит, выходим
STOP_ACTIVE=$(hook_field "$INPUT" '.stop_hook_active' 'false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

TRANSCRIPT=$(hook_field "$INPUT" '.transcript_path' '')
SESSION=$(hook_field "$INPUT" '.session_id')
CWD=$(hook_field "$INPUT" '.cwd')
PROJECT=$(hook_project_name "$CWD")

# Дефолты на случай отсутствия transcript
IN_TOK=0
OUT_TOK=0
CACHE_R=0
CACHE_W=0
TURNS=0
MODELS="[]"

if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # Суммируем usage по всем строкам — формат transcript:
  # каждая строка JSONL, в assistant-сообщениях есть .message.usage
  STATS=$(jq -s '
    map(select(.message.usage != null) | .message.usage) as $u
    | {
        input_tokens: ($u | map(.input_tokens // 0) | add // 0),
        output_tokens: ($u | map(.output_tokens // 0) | add // 0),
        cache_read: ($u | map(.cache_read_input_tokens // 0) | add // 0),
        cache_write: ($u | map(.cache_creation_input_tokens // 0) | add // 0),
        turns: ($u | length)
      }
  ' "$TRANSCRIPT" 2>/dev/null || echo '{}')

  IN_TOK=$(echo "$STATS" | jq -r '.input_tokens // 0')
  OUT_TOK=$(echo "$STATS" | jq -r '.output_tokens // 0')
  CACHE_R=$(echo "$STATS" | jq -r '.cache_read // 0')
  CACHE_W=$(echo "$STATS" | jq -r '.cache_write // 0')
  TURNS=$(echo "$STATS" | jq -r '.turns // 0')

  # Список использованных моделей в сессии
  MODELS=$(jq -s 'map(select(.message.model != null) | .message.model) | unique' "$TRANSCRIPT" 2>/dev/null || echo '[]')
fi

ENTRY=$(jq -n \
  --arg ts "$(hook_now)" \
  --arg sid "$SESSION" \
  --arg cwd "$CWD" \
  --arg proj "$PROJECT" \
  --argjson in "$IN_TOK" \
  --argjson out "$OUT_TOK" \
  --argjson cr "$CACHE_R" \
  --argjson cw "$CACHE_W" \
  --argjson turns "$TURNS" \
  --argjson models "$MODELS" \
  '{ts:$ts, session:$sid, project:$proj, cwd:$cwd, input_tokens:$in, output_tokens:$out, cache_read:$cr, cache_write:$cw, turns:$turns, models:$models}'
)

hook_log "stops" "$ENTRY"
exit 0
