#!/usr/bin/env bash
# PreToolUse / Read|Edit|Write|MultiEdit|Bash — блокирует доступ к секретам.
# Покрывает: .env и его варианты (кроме .example/.sample/.template/.dist и конфига direnv .envrc), ~/.ssh,
# ~/.aws, ~/.gnupg, ~/.kube/config и kubeconfig, id_rsa/id_ed25519, .pem/.p12/.pfx/.jks, .netrc, .pgpass,
# vault.yml, credentials.json.
# Для Bash блокируется чтение или копирование файла, а не упоминание имени: проверяются только аргументы-пути
# команды. `ls`, `find -name`, `echo`, `test -f`, `git check-ignore` и поиск по слову (`grep -rn ".env" docs/`)
# проходят. Тела heredoc не смотрим (cmdparse). Три ложные блокировки 2026-09-04 (.envrc в heredoc, grep по
# слову .env, echo с путём) закрыты именно этим.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')

# Путь похож на секрет: проверка по токену, не по подстроке всей команды.
SECRET_PATTERN='(\.env(\.[A-Za-z0-9_-]+)?$|(^|/)(id_rsa|id_ed25519|id_ecdsa|\.netrc|\.pgpass|kubeconfig|credentials\.json)$|/\.ssh/|/\.aws/|/\.gnupg/|/\.kube/config$|\.(pem|p12|pfx|jks)$|vault\.ya?ml$|gcloud/.*credentials)'
# Явно безопасные: примеры и шаблоны .env, конфиг direnv, зависимости и служебный каталог git.
SAFE_PATTERN='\.env\.(example|sample|template|dist)$|\.envrc$|/(node_modules|\.git)/'
# Команды, которым нужно только имя файла, не содержимое.
NAME_ONLY='^(ls|find|echo|printf|test|\[|\[\[|stat|file|which|basename|dirname|du|wc|true|false|cd|pwd|mkdir|touch)$'
# Поиск по содержимому: первый аргумент без дефиса — шаблон, а не путь.
SEARCH_CMDS='^(grep|egrep|fgrep|rg|ag|ack)$'

is_secret() {
  local p="$1"
  [ -n "$p" ] || return 1
  printf '%s' "$p" | grep -qE "$SAFE_PATTERN" && return 1
  printf '%s' "$p" | grep -qE "$SECRET_PATTERN"
}

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
    is_secret "$TARGET" && block "$TARGET"
    ;;
  Bash)
    CMD=$(hook_field "$INPUT" '.tool_input.command' '')
    [ -z "$CMD" ] && exit 0
    while IFS= read -r seg; do
      [ -z "$seg" ] && continue
      # Имя в фильтрах исключения/поиска — не чтение: --exclude '.env', -name '.env', -not -path '*/.ssh/*'
      seg=$(printf '%s' "$seg" | sed -E "s/(--exclude(-from)?|-name|-iname|-path|-not -name|-not -path)[= ]+('[^']*'|\"[^\"]*\"|[^[:space:]]+)//g")
      first=$(printf '%s' "$seg" | awk '{print $1}')
      second=$(printf '%s' "$seg" | awk '{print $2}')
      printf '%s' "$first" | grep -qE "$NAME_ONLY" && continue
      if [ "$first" = "git" ] && [[ "$second" =~ ^(status|check-ignore|ls-files|rm|clean|log)$ ]]; then
        continue
      fi
      skip_pattern=0
      printf '%s' "$first" | grep -qE "$SEARCH_CMDS" && skip_pattern=1
      i=0
      set -f
      for tok in $seg; do
        i=$((i + 1))
        [ "$i" -eq 1 ] && continue
        tok="${tok%\"}"; tok="${tok#\"}"; tok="${tok%\'}"; tok="${tok#\'}"
        tok="${tok#<}"; tok="${tok#>}"; tok="${tok#>}"
        case "$tok" in ''|-*) continue ;; esac
        if [ "$skip_pattern" = 1 ]; then skip_pattern=0; continue; fi
        is_secret "$tok" && block "$tok"
      done
      set +f
    done < <(cmd_segments "$CMD")
    ;;
  *) exit 0 ;;
esac
exit 0
