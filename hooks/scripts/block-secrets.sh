#!/usr/bin/env bash
# PreToolUse / Read|Edit|Write|Bash — блокирует доступ к секретам.
# Покрывает: .env (не .example/.sample), ~/.ssh/*, .pem, id_rsa,
# aws/credentials, vault.yml, .netrc, .pgpass.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')

# Куда смотреть зависит от инструмента
case "$TOOL" in
  Read|Edit|Write|MultiEdit)
    TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
    ;;
  Bash)
    TARGET=$(hook_field "$INPUT" '.tool_input.command' '')
    ;;
  *)
    exit 0
    ;;
esac

if [ -z "$TARGET" ]; then
  exit 0
fi

SECRET_PATTERN='(\.env([[:space:]]|$|[^.])|\.env\.local|\.env\.production|/\.ssh/|id_rsa|id_ed25519|\.pem([[:space:]]|$|[^a-z])|aws/credentials|\.netrc|\.pgpass|vault\.ya?ml|gcloud/.*credentials|kubeconfig)'

# Исключаем .env.example, .env.sample, .env.template
SAFE_PATTERN='\.env\.(example|sample|template|dist)'

if echo "$TARGET" | grep -qE "$SAFE_PATTERN"; then
  exit 0
fi

if echo "$TARGET" | grep -qE "$SECRET_PATTERN"; then
  hook_deny "Blocked: access to secret file/path. Open it manually if needed. Target: $(echo "$TARGET" | head -c 200)"
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg tgt "$TARGET" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$(hook_field "$INPUT" '.cwd')" '{ts:$ts, kind:"secret", tool:$tool, session:$sid, cwd:$cwd, target:$tgt}')"
  exit 0
fi

exit 0
