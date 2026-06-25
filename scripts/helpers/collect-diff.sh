#!/usr/bin/env bash
# Собирает дифф ветки относительно базы (three-dot) и блок метаданных для ревью.
# Используется командами ревью (/review, /review-mr), чтобы не дублировать
# git-обвязку в prose каждый запуск. Детерминированно, без правок репозитория.
#
# Использование:
#   collect-diff.sh [base] [branch]        # метаданные + three-dot дифф
#   collect-diff.sh --meta-only [base] [branch]   # только блок метаданных
#
# base   — база сравнения (default: master, иначе main). Если есть origin/<base>,
#          используется он (с предварительным git fetch); иначе локальный <base>.
# branch — ревьюимая ветка (default: текущая).

set -euo pipefail

META_ONLY=0
if [ "${1:-}" = "--meta-only" ]; then
  META_ONLY=1
  shift
fi

git rev-parse --git-dir >/dev/null 2>&1 || { echo "Не git-репозиторий" >&2; exit 1; }

# База: аргумент, иначе master, иначе main.
BASE_ARG="${1:-}"
if [ -n "$BASE_ARG" ]; then
  BASE_NAME="$BASE_ARG"
elif git rev-parse --verify -q master >/dev/null 2>&1 || git rev-parse --verify -q origin/master >/dev/null 2>&1; then
  BASE_NAME="master"
else
  BASE_NAME="main"
fi

BRANCH="${2:-$(git rev-parse --abbrev-ref HEAD)}"

# Если есть origin — подтянем его, чтобы база была свежей. Без origin не падаем.
if git remote get-url origin >/dev/null 2>&1; then
  git fetch -q origin || true
  if git rev-parse --verify -q "origin/$BASE_NAME" >/dev/null 2>&1; then
    BASE_REF="origin/$BASE_NAME"
  else
    BASE_REF="$BASE_NAME"
  fi
else
  BASE_REF="$BASE_NAME"
fi

git rev-parse --verify -q "$BASE_REF" >/dev/null 2>&1 || { echo "База не найдена: $BASE_REF" >&2; exit 1; }

PROJECT="$(basename "$(git rev-parse --show-toplevel)")"
AUTHOR="$(git log "$BASE_REF..$BRANCH" --format='%an' 2>/dev/null | sort | uniq -c | sort -rn | head -1 | sed -E 's/^ *[0-9]+ //')"
[ -n "$AUTHOR" ] || AUTHOR="$(git log -1 --format='%an' "$BRANCH" 2>/dev/null || echo unknown)"
SHORT_SHA="$(git rev-parse --short "$BASE_REF")"
DATE="$(date +%F)"

cat <<EOF
project: $PROJECT
branch: $BRANCH
author: $AUTHOR
base: $BASE_NAME ($BASE_REF @ $SHORT_SHA)
date: $DATE
EOF

if [ "$META_ONLY" -eq 0 ]; then
  echo "---"
  git diff "$BASE_REF...$BRANCH"
fi
