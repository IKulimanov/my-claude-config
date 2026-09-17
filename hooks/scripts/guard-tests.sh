#!/usr/bin/env bash
# PreToolUse / Edit|Write|MultiEdit|Bash — заморозка тестов (правило 06, вариант 1).
# Тест-файл, который есть в git и не изменён относительно HEAD, считается принятым: его правка,
# перезапись или удаление требует подтверждения (ask). Новые и уже изменённые тест-файлы,
# прод-код и чтение проходят без вопросов.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')
CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")

TEST_RE='((Test|Tests|IT)\.java|_test\.go|\.(spec|test)\.(ts|tsx|js|jsx))$'
WRITE_VERBS='^(tee|cp|mv|rm|rsync|ln|truncate|dd|patch|perl|python|python3|ruby)$'

# Файл заморожен: существует, отслеживается git и не отличается от HEAD.
is_frozen() {
  local f="$1" root
  [ -e "$f" ] || return 1
  root=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null) || return 1
  git -C "$root" ls-files --error-unmatch "$f" >/dev/null 2>&1 || return 1
  git -C "$root" diff --quiet HEAD -- "$f" 2>/dev/null
}

hit=""
case "$TOOL" in
  Edit|Write|MultiEdit)
    TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
    if [[ "$TARGET" =~ $TEST_RE ]] && is_frozen "$TARGET"; then hit="$TARGET"; fi
    ;;
  Bash)
    CMD=$(hook_field "$INPUT" '.tool_input.command' '')
    [ -z "$CMD" ] && exit 0
    cur_dir="$CWD"
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      new_dir=$(cmd_apply_cd "$seg" "$cur_dir")
      if [ "$new_dir" != "$cur_dir" ] || [[ "$seg" =~ ^cd([[:space:]]|$) ]]; then cur_dir="$new_dir"; continue; fi
      first=$(printf '%s' "$seg" | awk '{print $1}')
      second=$(printf '%s' "$seg" | awk '{print $2}')
      writes=0
      if printf '%s' "$seg" | grep -Eq '>{1,2}[[:space:]]*[^[:space:]]*((Test|Tests|IT)\.java|_test\.go|\.(spec|test)\.(ts|tsx|js|jsx))([[:space:]]|$)'; then writes=1
      elif [ "$first" = "sed" ] && [[ "$seg" =~ (^|[[:space:]])-i ]]; then writes=1
      elif printf '%s' "$first" | grep -Eq "$WRITE_VERBS"; then writes=1
      elif [ "$first" = "git" ] && [[ "$second" =~ ^(rm|mv)$ ]]; then writes=1
      fi
      [ "$writes" = 1 ] || continue
      for tok in $seg; do
        tok="${tok%\"}"; tok="${tok#\"}"; tok="${tok%\'}"; tok="${tok#\'}"
        [[ "$tok" =~ $TEST_RE ]] || continue
        path=$(cmd_resolve_dir "$tok" "$cur_dir")
        if is_frozen "$path"; then hit="$path"; break 2; fi
      done
    done < <(cmd_segments "$CMD")
    ;;
  *) exit 0 ;;
esac

[ -z "$hit" ] && exit 0

hook_ask "Правка закоммиченного теста $(basename "$hit"): согласованные тесты не меняются без вопроса оператору (правило 06) — подтверди."
hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg tgt "$hit" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" '{ts:$ts, kind:"test-freeze", decision:"ask", tool:$tool, session:$sid, project:$proj, cwd:$cwd, target:$tgt}')"
exit 0
