#!/usr/bin/env bash
# Тест collect-diff.sh: собирает метаданные ревью (проект, ветка, автор, база) и
# three-dot дифф ветки относительно базы. Без origin не делает fetch и не падает.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$SCRIPT_DIR/../scripts/helpers/collect-diff.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

git -C "$TMP" init -q -b main
git -C "$TMP" config user.email dev@example.com
git -C "$TMP" config user.name "Dev One"

# Базовый коммит на main.
printf 'line1\n' > "$TMP/app.txt"
git -C "$TMP" add app.txt
git -C "$TMP" commit -qm "init"

# Ветка с изменением.
git -C "$TMP" checkout -q -b feature/x
printf 'line1\nline2\n' > "$TMP/app.txt"
git -C "$TMP" commit -qam "add line2"

cd "$TMP"

# 1) Метаданные содержат проект, ветку, автора, базу.
meta=$("$COLLECT" --meta-only main) || fail "collect-diff --meta-only упал"
printf '%s\n' "$meta" | grep -qi "feature/x" || fail "нет ветки в метаданных: $meta"
printf '%s\n' "$meta" | grep -qi "Dev One"   || fail "нет автора в метаданных: $meta"
printf '%s\n' "$meta" | grep -qi "main"       || fail "нет базы в метаданных: $meta"

# 2) Полный вывод содержит и метаданные, и дифф с добавленной строкой.
full=$("$COLLECT" main) || fail "collect-diff упал"
printf '%s\n' "$full" | grep -q "+line2" || fail "дифф не содержит '+line2': $full"

echo "OK: test-collect-diff (метаданные + three-dot дифф без origin)"
