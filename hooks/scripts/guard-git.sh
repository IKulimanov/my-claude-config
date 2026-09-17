#!/usr/bin/env bash
# PreToolUse / Bash — политика git (правило 09).
# deny: push, merge, rebase, pull; checkout/switch на защищённую ветку; commit в защищённой ветке;
#       commit --no-verify.
# ask:  commit --amend, reset --hard, clean -f, branch -D, stash drop/clear, checkout/restore файлов.
# Разбор по сегментам команды, с учётом `cd` и `git -C`; тела heredoc не анализируются.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
CMD=$(hook_field "$INPUT" '.tool_input.command' '')
[ -z "$CMD" ] && exit 0
CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")

PROTECTED='^(master|main|staging|prod|production|prod-[^[:space:]]*)$'
DENY=""
ASK=""
cur_dir="$CWD"

while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  new_dir=$(cmd_apply_cd "$seg" "$cur_dir")
  if [ "$new_dir" != "$cur_dir" ] || [[ "$seg" =~ ^cd([[:space:]]|$) ]]; then
    cur_dir="$new_dir"
    continue
  fi
  rest=$(git_strip "$seg")
  [ -z "$rest" ] && continue
  sub=$(printf '%s' "$rest" | awk '{print $1}')
  args=$(printf '%s' "$rest" | sed -E 's/^[^[:space:]]+[[:space:]]*//')
  git_dir=$(cmd_resolve_dir "$(git_c_dir "$seg")" "$cur_dir")

  case "$sub" in
    push)
      DENY="git push запрещён: отправку в удалённый репозиторий делает пользователь (правило 09)." ;;
    merge)
      [[ "$args" =~ (^|[[:space:]])--abort ]] || DENY="git merge запрещён: слияние веток делает пользователь (правило 09)." ;;
    rebase)
      [[ "$args" =~ (^|[[:space:]])--abort ]] || DENY="git rebase запрещён: перепись истории делает пользователь (правило 09)." ;;
    pull)
      DENY="git pull запрещён: обновление из удалённого репозитория делает пользователь (правило 09)." ;;
    checkout|switch)
      if [[ "$args" =~ (^|[[:space:]])--([[:space:]]|$) ]]; then
        ASK="git $sub восстанавливает файлы из индекса или другой ветки и стирает локальные правки — подтверди."
      elif [[ "$args" =~ (^|[[:space:]])-[bBc]([[:space:]]|$) ]]; then
        :
      else
        target=$(printf '%s' "$args" | tr ' ' '\n' | grep -v '^-' | head -1 || true)
        if [[ -n "$target" && "$target" =~ $PROTECTED ]]; then
          DENY="Переключение на ветку $target запрещено: master/main/staging/prod меняет только пользователь (правило 09)."
        fi
      fi ;;
    commit)
      if [[ "$args" =~ (^|[[:space:]])(--no-verify|-n)([[:space:]]|$) ]]; then
        DENY="git commit --no-verify запрещён: обход pre-commit хуков (правило 09)."
      else
        branch=$(git -C "$git_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ -n "$branch" && "$branch" =~ $PROTECTED ]]; then
          DENY="Коммит в ветку $branch запрещён: создай рабочую ветку от master (правило 09)."
        elif [[ "$args" =~ (^|[[:space:]])--amend ]]; then
          ASK="git commit --amend переписывает последний коммит — подтверди."
        fi
      fi ;;
    reset)
      [[ "$args" =~ (^|[[:space:]])--hard ]] && ASK="git reset --hard стирает незакоммиченные изменения — подтверди." ;;
    clean)
      [[ "$args" =~ (^|[[:space:]])-[A-Za-z]*f ]] && ASK="git clean -f удаляет неотслеживаемые файлы — подтверди." ;;
    branch)
      [[ "$args" =~ (^|[[:space:]])(-D|--delete[[:space:]]+--force|--force[[:space:]]+--delete)([[:space:]]|$) ]] && ASK="git branch -D удаляет ветку без проверки слияния — подтверди." ;;
    stash)
      [[ "$args" =~ ^(drop|clear)([[:space:]]|$) ]] && ASK="git stash $sub удаляет отложенные изменения — подтверди." ;;
    restore)
      [[ "$args" =~ (^|[[:space:]])--staged ]] || ASK="git restore стирает локальные правки файла — подтверди." ;;
  esac
done < <(cmd_segments "$CMD")

log_decision() {
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg d "$1" --arg cmd "$(printf '%s' "$CMD" | head -c 300)" \
    --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" \
    '{ts:$ts, kind:"git", decision:$d, session:$sid, project:$proj, cwd:$cwd, command:$cmd}')"
}

if [ -n "$DENY" ]; then
  hook_deny "$DENY"
  log_decision deny
  exit 0
fi
if [ -n "$ASK" ]; then
  hook_ask "$ASK"
  log_decision ask
  exit 0
fi
exit 0
