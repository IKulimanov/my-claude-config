#!/usr/bin/env bash
# PreToolUse / Edit|Write|MultiEdit|Bash — защищённые пути (правило 09): .gitlab-ci.yml, .gitlab/, helm/.
# Запись в них — только по явной просьбе, поэтому хук возвращает ask; чтение не трогаем.
# Добавки на проект — через permissions.ask в .claude/settings.local.json проекта.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')
CWD=$(hook_field "$INPUT" '.cwd')

# Для пути инструмента граница — начало или «/»; для Bash-команды путь стоит после пробела,
# знака «=», кавычки или редиректа.
PROTECTED_RE='(^|/)(\.gitlab-ci\.ya?ml|\.gitlab/|helm/)'
PROTECTED_RE_CMD='(^|[[:space:]/=>"'"'"'])(\.gitlab-ci\.ya?ml|\.gitlab/|helm/)'
WRITE_VERBS='^(tee|cp|mv|rm|rsync|ln|truncate|chmod|chown|dd|install|patch|perl|python|python3|ruby)$'
REASON="Защищённый путь (.gitlab-ci.yml, .gitlab/, helm/): правка только по явной просьбе — подтверди (правило 09)."

hit=""
case "$TOOL" in
  Edit|Write|MultiEdit)
    TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
    if printf '%s' "$TARGET" | grep -Eq "$PROTECTED_RE"; then hit="$TARGET"; fi
    ;;
  Bash)
    CMD=$(hook_field "$INPUT" '.tool_input.command' '')
    [ -z "$CMD" ] && exit 0
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      printf '%s' "$seg" | grep -Eq "$PROTECTED_RE_CMD" || continue
      first=$(printf '%s' "$seg" | awk '{print $1}')
      second=$(printf '%s' "$seg" | awk '{print $2}')
      if printf '%s' "$seg" | grep -Eq '>{1,2}[[:space:]]*[^[:space:]]*(\.gitlab-ci\.ya?ml|\.gitlab/|helm/)'; then
        hit="$seg"
      elif [ "$first" = "sed" ] && [[ "$seg" =~ (^|[[:space:]])-i ]]; then
        hit="$seg"
      elif printf '%s' "$first" | grep -Eq "$WRITE_VERBS"; then
        hit="$seg"
      elif [ "$first" = "git" ] && [[ "$second" =~ ^(rm|mv)$ ]]; then
        hit="$seg"
      fi
      [ -n "$hit" ] && break
    done < <(cmd_segments "$CMD")
    ;;
  *) exit 0 ;;
esac

[ -z "$hit" ] && exit 0

hook_ask "$REASON"
hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg tgt "$(printf '%s' "$hit" | head -c 300)" \
  --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" \
  '{ts:$ts, kind:"protected-path", decision:"ask", tool:$tool, session:$sid, project:$proj, cwd:$cwd, target:$tgt}')"
exit 0
