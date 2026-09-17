#!/usr/bin/env bash
# PreToolUse / Bash — блокирует разрушительные команды: rm -rf вне сборочных и scratch-каталогов,
# DROP/TRUNCATE, chmod 777, mkfs, запись в /dev/sd*. Политика git — в guard-git.sh.
# Регексы покрывают типовые случаи; обход через хитрое квотирование возможен — это один из слоёв,
# второй — permissions в settings.json, третий — правило 09.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
CMD=$(hook_field "$INPUT" '.tool_input.command' '')
[ -z "$CMD" ] && exit 0
CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")

# Что можно удалять рекурсивно: сборочные каталоги и scratch-каталоги сессии Claude.
# Относительные цели приводятся к абсолютному пути с учётом `cd` в той же команде.
SAFE_TARGET='(^|/)(target|build|dist|node_modules|out|\.gradle)(/.*)?$|^/private/tmp/claude-|^/tmp/claude-'
REASON=""
cur_dir="$CWD"

while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  new_dir=$(cmd_apply_cd "$seg" "$cur_dir")
  if [ "$new_dir" != "$cur_dir" ] || [[ "$seg" =~ ^cd([[:space:]]|$) ]]; then
    cur_dir="$new_dir"
    continue
  fi
  [[ "$seg" =~ ^(sudo[[:space:]]+)?rm([[:space:]]|$) ]] || continue
  flags=""
  targets=()
  for tok in $(printf '%s' "$seg" | sed -E 's/^(sudo[[:space:]]+)?rm//'); do
    case "$tok" in
      --recursive) flags="${flags}r" ;;
      --force)     flags="${flags}f" ;;
      --*)         ;;
      -*)          flags="${flags}${tok#-}" ;;
      *)           targets+=("$tok") ;;
    esac
  done
  { [[ "$flags" == *r* ]] || [[ "$flags" == *R* ]]; } && [[ "$flags" == *f* ]] || continue
  if [ "${#targets[@]}" -eq 0 ]; then
    REASON="rm -rf без явных целей"
    break
  fi
  for t in "${targets[@]}"; do
    t="${t%\"}"; t="${t#\"}"; t="${t%\'}"; t="${t#\'}"
    t=$(cmd_resolve_dir "$t" "$cur_dir")
    if ! printf '%s' "$t" | grep -Eq "$SAFE_TARGET"; then
      REASON="rm -rf $t — удаление вне сборочных (target, build, dist, node_modules) и scratch-каталогов"
      break 2
    fi
  done
done < <(cmd_segments "$CMD")

OTHER='(\bDROP[[:space:]]+TABLE\b|\bDROP[[:space:]]+DATABASE\b|\bTRUNCATE[[:space:]]+TABLE\b|\bchmod[[:space:]]+777\b|\bmkfs\.|:>/dev/sd)'
if [ -z "$REASON" ] && printf '%s' "$CMD" | grep -qiE "$OTHER"; then
  REASON="разрушительная команда (DROP/TRUNCATE/chmod 777/mkfs/запись в устройство)"
fi

if [ -n "$REASON" ]; then
  hook_deny "Заблокировано: $REASON. Выполни вручную, если это действительно нужно. Команда: $(printf '%s' "$CMD" | head -c 200)"
  CWD=$(hook_field "$INPUT" '.cwd')
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg cmd "$CMD" --arg r "$REASON" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" '{ts:$ts, kind:"destructive", decision:"deny", reason:$r, session:$sid, project:$proj, cwd:$cwd, command:$cmd}')"
fi
exit 0
