#!/usr/bin/env bash
# Каталог артефактов задачи: <корень репозитория>/.claude/tasks/<ключ>/ с подпапкой agent/.
# Ключ — из имени ветки (Jira-ID, иначе имя без типового префикса; scripts/lib/task-dir.sh) или из явного
# имени. Вызывается командами (/task, /feature, /review, /review-mr), действует сразу, без --apply.
# Старый каталог .ai/ (если git его не отслеживает) переезжает в .claude/tasks/ целиком.
# .gitignore проекта не трогает: .claude/tasks/ игнорируется глобальным excludes (setup-global.sh).
#
#   ai-init.sh            # каталог текущей ветки: последний существующий или новый <ключ>/
#   ai-init.sh --new      # доработка: следующий номер <ключ>-2, <ключ>-3 …
#   ai-init.sh <имя>      # явное имя вместо ветки (ветка коллеги для /review-mr, старое имя задачи)
#   ai-init.sh -n …       # dry-run: только напечатать путь
#
# В stdout — абсолютный путь каталога единственной строкой; замечания о переезде — в stderr.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/task-dir.sh"

DRY_RUN=0; NEW=0; NAME=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1; shift ;;
    --new) NEW=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    -*) echo "Неизвестный флаг: $1" >&2; exit 1 ;;
    *) NAME="$1"; shift ;;
  esac
done

ROOT=$(task_repo_root .)
IN_GIT=0
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 && IN_GIT=1

if [ -n "$NAME" ]; then
  KEY=$(task_key "$NAME")
else
  BRANCH=$(task_branch "$ROOT")
  if [ -z "$BRANCH" ] && [ "$IN_GIT" = 1 ]; then
    BRANCH="detached-$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo head)"
  fi
  KEY=$(task_key "${BRANCH:-task}")
fi

# Переезд старого .ai/: каждый элемент — в .claude/tasks/, занятые имена остаются с предупреждением.
migrate_legacy() {
  local legacy="$ROOT/.ai" tasks="$ROOT/.claude/tasks" d name
  [ -d "$legacy" ] || return 0
  if [ "$IN_GIT" = 1 ] && [ -n "$(git -C "$ROOT" ls-files .ai | head -1)" ]; then
    echo "ai-init: .ai/ отслеживается git — не переношу" >&2
    return 0
  fi
  mkdir -p "$tasks"
  for d in "$legacy"/*; do
    [ -e "$d" ] || continue
    name=$(basename "$d")
    if [ -e "$tasks/$name" ]; then
      echo "ai-init: .ai/$name не перенесён — .claude/tasks/$name уже есть" >&2
      continue
    fi
    mv "$d" "$tasks/$name"
    echo "ai-init: .ai/$name → .claude/tasks/$name" >&2
  done
  if rmdir "$legacy" 2>/dev/null; then
    echo "ai-init: пустой .ai/ убран" >&2
  else
    echo "ai-init: в .ai/ остались файлы — разбери руками" >&2
  fi
}

[ "$DRY_RUN" = 1 ] || migrate_legacy

if [ "$NEW" = 1 ]; then
  DIR=$(task_dir_next "$ROOT" "$KEY")
else
  DIR=$(task_dir_latest "$ROOT" "$KEY")
  [ -n "$DIR" ] || DIR="$ROOT/.claude/tasks/$KEY"
fi

[ "$DRY_RUN" = 1 ] || mkdir -p "$DIR/agent"
printf '%s\n' "$DIR"
