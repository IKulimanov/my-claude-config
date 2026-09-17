#!/usr/bin/env bash
# PreToolUse / Read|Edit|Write|MultiEdit|Bash — блокирует доступ к секретам.
# Покрывает: .env (не .example/.sample), ~/.ssh/*, .pem, id_rsa, aws/credentials, vault.yml, .netrc, .pgpass.
# Для Bash блокируется чтение или копирование файла, а не упоминание имени: `ls`, `find -name`,
# `echo`, `test -f`, `git check-ignore` проходят.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')

SECRET_PATTERN='(\.env([[:space:]]|$|[^.])|\.env\.local|\.env\.production|/\.ssh/|id_rsa|id_ed25519|\.pem([[:space:]]|$|[^a-z])|aws/credentials|\.netrc|\.pgpass|vault\.ya?ml|gcloud/.*credentials|kubeconfig)'
# .env.example, .env.sample, .env.template, .env.dist — не секреты
SAFE_PATTERN='\.env\.(example|sample|template|dist)'
# Команды, которым нужно только имя файла, не содержимое
NAME_ONLY='^(ls|find|echo|printf|test|\[|\[\[|stat|file|which|basename|dirname|du|wc|true|false|cd|pwd|mkdir|touch)$'

block() {
  hook_deny "Заблокировано: доступ к секретному файлу. Открой его вручную, если нужно. Цель: $(printf '%s' "$1" | head -c 200)"
  CWD=$(hook_field "$INPUT" '.cwd')
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg tgt "$1" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" '{ts:$ts, kind:"secret", decision:"deny", tool:$tool, session:$sid, project:$proj, cwd:$cwd, target:$tgt}')"
  exit 0
}

case "$TOOL" in
  Read|Edit|Write|MultiEdit)
    TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
    [ -z "$TARGET" ] && exit 0
    printf '%s' "$TARGET" | grep -qE "$SAFE_PATTERN" && exit 0
    printf '%s' "$TARGET" | grep -qE "$SECRET_PATTERN" && block "$TARGET"
    ;;
  Bash)
    CMD=$(hook_field "$INPUT" '.tool_input.command' '')
    [ -z "$CMD" ] && exit 0
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      printf '%s' "$seg" | grep -qE "$SECRET_PATTERN" || continue
      printf '%s' "$seg" | grep -qE "$SAFE_PATTERN" && continue
      first=$(printf '%s' "$seg" | awk '{print $1}')
      second=$(printf '%s' "$seg" | awk '{print $2}')
      printf '%s' "$first" | grep -qE "$NAME_ONLY" && continue
      if [ "$first" = "git" ] && [[ "$second" =~ ^(status|check-ignore|ls-files|rm|clean|log)$ ]]; then
        continue
      fi
      block "$seg"
    done < <(cmd_segments "$CMD")
    ;;
  *) exit 0 ;;
esac
exit 0
