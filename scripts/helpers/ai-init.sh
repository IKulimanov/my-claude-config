#!/usr/bin/env bash
# Создаёт скелет директории артефактов .ai/<feature>/ в текущем рабочем репозитории
# и гарантирует, что .ai/ игнорируется git. Вызывается командами (/feature, /plan,
# /review, /task), а не вручную для установки — поэтому действует сразу, без --apply.
# Идемпотентен и низкорисковен (трогает только локальный .ai/ и .gitignore репозитория).
#
# Использование:
#   ai-init.sh <feature> [letter]   # создать .ai/<feature>/ (+ подпапку <letter>/ для heavy-режима)
#   ai-init.sh -n <feature>         # dry-run: показать, что было бы создано, ничего не меняя
#
# Печатает в stdout абсолютный путь созданной директории (последней строкой),
# чтобы вызывающая команда могла его захватить.

set -euo pipefail

DRY_RUN=0
if [ "${1:-}" = "-n" ] || [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

FEATURE_RAW="${1:-}"
LETTER="${2:-}"

if [ -z "$FEATURE_RAW" ]; then
  echo "Usage: ai-init.sh [-n] <feature> [letter]" >&2
  exit 1
fi

# Кебаб-кейс: нижний регистр, неалфанумерик -> дефис, схлопнуть и обрезать дефисы.
kebab() {
  printf '%s' "$1" \
    | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/-+/-/g; s/^-//; s/-$//'
}

FEATURE="$(kebab "$FEATURE_RAW")"
[ -n "$FEATURE" ] || { echo "Имя фичи пустое после нормализации: '$FEATURE_RAW'" >&2; exit 1; }

# Корень репозитория, иначе текущая директория.
if REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  REPO_ROOT="$(pwd)"
fi

TARGET="$REPO_ROOT/.ai/$FEATURE"
[ -n "$LETTER" ] && TARGET="$TARGET/$LETTER"

GITIGNORE="$REPO_ROOT/.gitignore"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[dry-run] mkdir -p $TARGET"
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF ".ai/" "$GITIGNORE" 2>/dev/null; then
    echo "[dry-run] добавил бы '.ai/' в $GITIGNORE"
  fi
  echo "$TARGET"
  exit 0
fi

mkdir -p "$TARGET"

# Гарантируем .ai/ в .gitignore ровно один раз (только внутри git-репозитория).
if git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  if [ ! -f "$GITIGNORE" ] || ! grep -qxF ".ai/" "$GITIGNORE"; then
    printf '.ai/\n' >> "$GITIGNORE"
  fi
fi

echo "$TARGET"
