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

# Порог ротации журнала в мегабайтах. tools.jsonl на прежней машине дорос до 28 МБ —
# после этого его тяжело читать скриптами аудита и он замедляет каждый разбор.
LOG_MAX_MB="${CLAUDE_LOG_MAX_MB:-20}"

# Отрезать журнал, если он перерос порог: переименовать в <name>-<дата>.jsonl.
# Старые срезы не удаляем — их читает месячный аудит.
hook_log_rotate() {
  local file="$1"
  [ -f "$file" ] || return 0
  local size_mb
  size_mb=$(( $(wc -c < "$file" 2>/dev/null || echo 0) / 1048576 ))
  [ "$size_mb" -lt "$LOG_MAX_MB" ] && return 0
  mv "$file" "${file%.jsonl}-$(date -u +%Y%m%d-%H%M%S).jsonl" 2>/dev/null || true
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
  hook_log_rotate "$LOG_DIR/$name.jsonl"
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

# Отдать JSON-ответ для PreToolUse-ask: действие показывается пользователю с причиной.
# Args: <reason>
hook_ask() {
  local reason="$1"
  jq -n --arg r "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $r}}'
}

# Профиль проекта по правилу 10: строка «Тип проекта: work|personal» в CLAUDE.md корня репозитория →
# каталог WORK_ROOT (CLAUDE_WORK_ROOT для тестов → workspace.conf репозитория конфига, файл задаёт
# CLAUDE_WORKSPACE_CONF → $HOME/dev/work) → personal. Пути сравниваются после pwd -P: /var и /private/var.
# Args: <каталог> -> печатает work | personal
hook_project_profile() {
  local dir="${1:-$(pwd)}" root line work_root conf conf_root
  root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || root="$dir"
  if [ -f "$root/CLAUDE.md" ]; then
    line=$(grep -m1 -oE 'Тип проекта:[[:space:]]*(work|personal)' "$root/CLAUDE.md" 2>/dev/null || true)
    case "$line" in
      *work) echo work; return 0 ;;
      *personal) echo personal; return 0 ;;
    esac
  fi
  if [ -n "${CLAUDE_WORK_ROOT:-}" ]; then
    work_root="$CLAUDE_WORK_ROOT"
  else
    work_root="$HOME/dev/work"
    conf="${CLAUDE_WORKSPACE_CONF:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/workspace.conf}"
    if [ -f "$conf" ]; then
      conf_root=$(sh -c ". '$conf' 2>/dev/null; printf '%s' \"\${WORK_ROOT:-}\"") || conf_root=""
      [ -n "$conf_root" ] && work_root="$conf_root"
    fi
  fi
  work_root=$(cd "$work_root" 2>/dev/null && pwd -P) || { echo personal; return 0; }
  root=$(cd "$root" 2>/dev/null && pwd -P) || root="$dir"
  case "$root/" in
    "$work_root"/*) echo work ;;
    *) echo personal ;;
  esac
}
