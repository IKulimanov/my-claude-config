#!/usr/bin/env bash
# Общие helper-функции для всех хуков.
# Source через: . "$(dirname "$0")/lib/common.sh"

set -euo pipefail

LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}"
mkdir -p "$LOG_DIR"

# Вернёт basename($cwd) — короткое имя проекта для агрегации.
hook_project_name() {
  local cwd="${1:-}"
  [ -z "$cwd" ] && cwd=$(pwd)
  basename "$cwd"
}

# Append одной JSON-записи в лог-файл строго как одна строка JSONL.
# Компактизируем payload (jq -c), чтобы многострочный pretty-JSON не ломал
# поток при частичной/гонке записи. Невалидный payload — как fallback
# схлопываем переводы строк, чтобы запись всё равно осталась однострочной.
# Args: <log_basename> <json_payload>
hook_log() {
  local name="$1"
  local payload="$2"
  local line
  line=$(jq -c . <<<"$payload" 2>/dev/null) || line=$(printf '%s' "$payload" | tr -d '\n')
  printf '%s\n' "$line" >> "$LOG_DIR/$name.jsonl"
}

# Считать stdin в переменную INPUT.
# Использование: INPUT=$(hook_read_input)
hook_read_input() {
  cat
}

# Извлечь поле из INPUT через jq, с дефолтом.
# Args: <input_json> <jq_path> [default]
hook_field() {
  local input="$1"
  local path="$2"
  local default="${3:-}"
  echo "$input" | jq -r "$path // \"$default\""
}

# Отдать JSON-ответ для PreToolUse-deny.
# Args: <reason>
hook_deny() {
  local reason="$1"
  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
}

# Текущий ISO timestamp в UTC.
hook_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Извлечь slash-команду из промпта: только ведущий /token первой строки.
# Через BASH_REMATCH (не awk '{print $1}', который на многострочном промпте
# печатал первый токен КАЖДОЙ строки и «протекал» в значение — "at", "<td", "|").
# Args: <prompt> -> печатает "/command" либо ничего.
hook_slash_command() {
  local prompt="$1"
  # Команда — это /token, за которым пробел/перевод строки/конец. Хвостовая
  # граница отсекает абсолютные пути (/Users/...), которые тоже начинаются с "/".
  # ":" разрешён ради namespaced-команд плагинов (/plugin:command).
  if [[ "$prompt" =~ ^(/[A-Za-z][A-Za-z0-9_:-]*)([[:space:]]|$) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}
