#!/usr/bin/env bash
# Устанавливает базовые настройки в ~/.claude/settings.json — глобально для всех проектов:
# hooks, permissions (allow/deny), cleanupPeriodDays.
# Подменяет плейсхолдер HOOKS_DIR на реальный абсолютный путь к скриптам.
# permissions объединяются с существующими, hooks и cleanupPeriodDays перезаписываются.
#
# Использование:
#   ./scripts/install-hooks.sh         # печатает merge-инструкцию
#   ./scripts/install-hooks.sh --write # пишет напрямую в ~/.claude/settings.json (с бэкапом)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$ROOT_DIR/hooks/scripts"
SRC="$ROOT_DIR/hooks/settings.json"
TARGET="$HOME/.claude/settings.json"

if [ ! -d "$HOOKS_DIR" ]; then
  echo "Hooks dir not found: $HOOKS_DIR" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required. Install: brew install jq" >&2
  exit 1
fi

RENDERED=$(sed -e "s|HOOKS_DIR|$HOOKS_DIR|g" "$SRC")

MODE="${1:-print}"

if [ "$MODE" = "--write" ]; then
  mkdir -p "$HOME/.claude"
  if [ -f "$TARGET" ]; then
    BACKUP="$TARGET.bak.$(date +%s)"
    cp "$TARGET" "$BACKUP"
    echo "Backup saved: $BACKUP"

    # Merge: hooks и cleanupPeriodDays перезаписываем своими, permissions ОБЪЕДИНЯЕМ —
    # чтобы не стереть разрешения, которые пользователь добавил сам.
    # Идемпотентно: повторный запуск даёт тот же результат.
    MERGED=$(jq -s '
      .[0] as $cur | .[1] as $new
      | $cur
      * { hooks: $new.hooks, cleanupPeriodDays: $new.cleanupPeriodDays }
      * { permissions: (
            ($cur.permissions // {})
            * { allow: ((($cur.permissions.allow // []) + ($new.permissions.allow // [])) | unique),
                deny:  ((($cur.permissions.deny  // []) + ($new.permissions.deny  // [])) | unique) }
          ) }
    ' "$TARGET" <(echo "$RENDERED"))
    echo "$MERGED" | jq '.' > "$TARGET"
  else
    echo "$RENDERED" | jq 'del(._comment, ._install)' > "$TARGET"
  fi
  echo "Installed hooks to: $TARGET"
  echo "Test with: claude --debug, затем посмотри ~/.claude/logs/*.jsonl"
else
  echo "# Скопируй блок ниже в ~/.claude/settings.json (под ключ 'hooks'):"
  echo
  echo "$RENDERED" | jq '.hooks'
  echo
  echo "# или запусти: $0 --write"
fi
