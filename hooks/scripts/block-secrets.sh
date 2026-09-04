#!/usr/bin/env bash
# PreToolUse / Read|Edit|Write|Bash — блокирует доступ к секретам.
#
# Два разных режима, потому что у них разная цена ошибки:
#
# 1. Read/Edit/Write — проверяем tool_input.file_path. Это точный путь, ложных
#    срабатываний быть не может. Дублирует permissions.deny в settings.json и
#    работает как подстраховка, если deny забыли обновить.
#
# 2. Bash — проверяем НЕ всю строку команды, а только аргументы команд, которые
#    реально читают или копируют файл (cat, cp, scp, source и т.п.). Раньше здесь
#    был поиск подстроки по всей команде: он блокировал `grep .env docs/`,
#    комментарий со словом `.envrc` и любое упоминание пути в тексте скрипта.
#    Проверено на практике: три ложные блокировки за первые минуты работы.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')

# Пути к секретам. Совпадение ищется по токену, похожему на путь, а не по любому вхождению.
SECRET_PATTERN='(^|/)(\.env|\.env\.local|\.env\.production|id_rsa|id_ed25519|\.netrc|\.pgpass|kubeconfig|credentials)$|/\.ssh/|/\.aws/credentials|/\.gnupg/|\.pem$|\.p12$|\.jks$|vault\.ya?ml$'

# Явно безопасные: примеры, шаблоны и конфиг direnv (это не хранилище секретов, а список
# переменных окружения проекта; именно он дал первое ложное срабатывание).
SAFE_PATTERN='\.env\.(example|sample|template|dist)$|\.envrc$|\.env\.example|/(node_modules|\.git)/'

# Команды, которые действительно достают содержимое файла или копируют его наружу.
READER_CMDS='cat|bat|less|more|head|tail|xxd|od|base64|strings|cp|mv|scp|rsync|install|source|\.|open|pbcopy|tar|zip'

is_secret_path() {
  local p="$1"
  [ -z "$p" ] && return 1
  echo "$p" | grep -qE "$SAFE_PATTERN" && return 1
  echo "$p" | grep -qE "$SECRET_PATTERN"
}

case "$TOOL" in
  Read|Edit|Write|MultiEdit)
    TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
    if is_secret_path "$TARGET"; then
      REASON="Blocked: доступ к файлу секретов. Открой вручную, если это осознанно. Файл: $(echo "$TARGET" | head -c 200)"
    else
      exit 0
    fi
    ;;
  Bash)
    CMD=$(hook_field "$INPUT" '.tool_input.command' '')
    [ -z "$CMD" ] && exit 0

    # Достаём аргументы только у читающих команд: <команда> <аргументы до | ; & конца строки>.
    # Каждый аргумент проверяем как путь. Всё остальное в команде игнорируем.
    ARGS=$(echo "$CMD" \
      | grep -oE "(^|[|;&[:space:]])(${READER_CMDS})[[:space:]]+[^|;&]*" \
      | sed -E "s/^[|;&[:space:]]*(${READER_CMDS})[[:space:]]+//" \
      | tr ' \t' '\n\n' | tr -d "\"'" || true)

    HIT=""
    while IFS= read -r arg; do
      [ -z "$arg" ] && continue
      case "$arg" in -*) continue ;; esac   # флаги не пути
      if is_secret_path "$arg"; then HIT="$arg"; break; fi
    done <<< "$ARGS"

    if [ -n "$HIT" ]; then
      REASON="Blocked: команда читает файл секретов. Запусти вручную, если это осознанно. Аргумент: $(echo "$HIT" | head -c 200)"
      TARGET="$HIT"
    else
      exit 0
    fi
    ;;
  *)
    exit 0
    ;;
esac

hook_deny "$REASON"
CWD=$(hook_field "$INPUT" '.cwd')
hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg tgt "$TARGET" --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" '{ts:$ts, kind:"secret", tool:$tool, session:$sid, project:$proj, cwd:$cwd, target:$tgt}')"
exit 0
