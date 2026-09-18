#!/usr/bin/env bash
# Устанавливает хуки и permissions из hooks/settings.json в ~/.claude/settings.json — глобально.
# Подменяет плейсхолдер HOOKS_DIR на абсолютный путь к скриптам.
# Слияние: секция hooks заменяется целиком; permissions.allow, deny и ask объединяются с существующими
# без дублей (свои записи пользователя остаются); прочие ключи не трогаются. Повторный запуск ничего
# не меняет.
#
# Использование:
#   ./scripts/install-hooks.sh         # печатает, что будет установлено
#   ./scripts/install-hooks.sh --write # пишет в ~/.claude/settings.json (с бэкапом)
# Для тестов: CLAUDE_SETTINGS_TARGET=/path/to/settings.json

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$ROOT_DIR/hooks/scripts"
SRC="$ROOT_DIR/hooks/settings.json"
TARGET="${CLAUDE_SETTINGS_TARGET:-$HOME/.claude/settings.json}"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "Hooks dir not found: $HOOKS_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install: brew install jq" >&2
  exit 1
fi

RENDERED=$(sed -e "s|HOOKS_DIR|$HOOKS_DIR|g" "$SRC" | jq 'del(._comment, ._install)')

MODE="${1:-print}"

if [ "$MODE" = "--write" ]; then
  mkdir -p "$(dirname "$TARGET")"
  if [ -f "$TARGET" ]; then
    BACKUP="$TARGET.bak.$(date +%s)"
    cp "$TARGET" "$BACKUP"
    echo "Backup saved: $BACKUP"
    MERGED=$(jq -s '
      .[0] as $cur | .[1] as $new |
      $cur
      | .hooks = $new.hooks
      | .permissions = (($cur.permissions // {})
          | .allow = (((.allow // []) + ($new.permissions.allow // [])) | unique)
          | .deny = (((.deny // []) + ($new.permissions.deny // [])) | unique)
          | .ask  = (((.ask  // []) + ($new.permissions.ask  // [])) | unique))
    ' "$TARGET" <(printf '%s' "$RENDERED"))
    printf '%s\n' "$MERGED" | jq '.' > "$TARGET"
  else
    printf '%s\n' "$RENDERED" | jq '.' > "$TARGET"
  fi
  echo "Installed hooks and permissions to: $TARGET"
else
  echo "# Будет установлено в $TARGET (секции hooks и permissions.allow/deny/ask):"
  echo
  printf '%s\n' "$RENDERED" | jq '{permissions, hooks}'
  echo
  echo "# Применить: $0 --write"
fi
