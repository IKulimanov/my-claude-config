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

# Append одной JSON-записи в лог-файл. Атомарный append (>>).
# Args: <log_basename> <json_payload>
hook_log() {
  local name="$1"
  local payload="$2"
  echo "$payload" >> "$LOG_DIR/$name.jsonl"
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
