#!/usr/bin/env bash
# Общие функции для тестов PreToolUse-хуков: сборка входа и проверка решения.
# Подключение: . "$(dirname "$0")/lib/hooktest.sh"; hooktest_init

hooktest_init() {
  TMP=$(mktemp -d)
  export CLAUDE_LOG_DIR="$TMP/logs"
  trap 'rm -rf "$TMP"' EXIT
}

fail() { echo "FAIL: $1" >&2; exit 1; }

# Решение хука для одного вызова инструмента.
# Args: <hook> <tool> <cwd> <command-или-путь> -> печатает allow | ask | deny
hook_decision() {
  local hook="$1" tool="$2" cwd="$3" arg="$4" input out
  case "$tool" in
    Bash)
      input=$(jq -cn --arg t "$tool" --arg c "$arg" --arg d "$cwd" \
        '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$c},session_id:"test",cwd:$d}')
      ;;
    *)
      input=$(jq -cn --arg t "$tool" --arg f "$arg" --arg d "$cwd" \
        '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{file_path:$f},session_id:"test",cwd:$d}')
      ;;
  esac
  out=$(printf '%s' "$input" | "$hook")
  if [ -z "$out" ]; then
    echo allow
  else
    printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'
  fi
}

# Проверка: <hook> <ожидание> <tool> <cwd> <command-или-путь>
expect_decision() {
  local got
  got=$(hook_decision "$1" "$3" "$4" "$5")
  [ "$got" = "$2" ] || fail "$3 «$5» (cwd $4): ожидалось $2, получено $got"
}
