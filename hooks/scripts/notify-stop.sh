#!/usr/bin/env bash
# Stop — отправляет macOS notification когда Claude закончил отвечать.
# Linux: через notify-send (если libnotify установлен).
# Защита от Stop-петли через stop_hook_active.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)

# Анти-петля: если stop хук уже активен, выходим без действий
STOP_ACTIVE=$(hook_field "$INPUT" '.stop_hook_active' 'false')
if [ "$STOP_ACTIVE" = "true" ]; then
  exit 0
fi

CWD=$(hook_field "$INPUT" '.cwd' '')
PROJECT=$(hook_project_name "$CWD")
TITLE="Claude Code"
MSG="Готово · $PROJECT"

case "$(uname -s)" in
  Darwin)
    # display notification — без зависимостей
    osascript -e "display notification \"$MSG\" with title \"$TITLE\" sound name \"Glass\"" >/dev/null 2>&1 || true
    ;;
  Linux)
    if command -v notify-send >/dev/null 2>&1; then
      notify-send "$TITLE" "$MSG" || true
    fi
    ;;
esac

exit 0
