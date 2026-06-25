#!/usr/bin/env bash
# Тест ai-init.sh: создаёт скелет .ai/<feature>/, добавляет .ai/ в .gitignore один раз,
# идемпотентен, поддерживает heavy-режим (буква задачи) и dry-run.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_INIT="$SCRIPT_DIR/../scripts/helpers/ai-init.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# Готовим временный git-репозиторий.
git -C "$TMP" init -q
git -C "$TMP" config user.email t@t.t
git -C "$TMP" config user.name t

cd "$TMP"

# 1) Light-режим: создаётся .ai/<feature>/, путь печатается в stdout.
out=$("$AI_INIT" "My Feature") || fail "ai-init вышел с ошибкой"
[ -d "$TMP/.ai/my-feature" ] || fail "не создан .ai/my-feature (кебаб из 'My Feature')"
printf '%s\n' "$out" | grep -q ".ai/my-feature" || fail "путь не напечатан в stdout: '$out'"

# 2) .ai/ добавлен в .gitignore.
grep -qxF ".ai/" "$TMP/.gitignore" || fail ".ai/ не добавлен в .gitignore"

# 3) Идемпотентность: повтор не дублирует строку в .gitignore и не падает.
"$AI_INIT" "My Feature" >/dev/null || fail "повторный запуск упал"
count=$(grep -cxF ".ai/" "$TMP/.gitignore")
[ "$count" -eq 1 ] || fail ".ai/ продублирован в .gitignore ($count раз)"

# 4) Heavy-режим: буква задачи создаёт подпапку .ai/<feature>/<letter>/.
"$AI_INIT" big-feature a >/dev/null || fail "heavy-режим упал"
[ -d "$TMP/.ai/big-feature/a" ] || fail "не создана подпапка .ai/big-feature/a"

# 5) Dry-run: ничего не создаёт.
"$AI_INIT" -n dry-feature >/dev/null || fail "dry-run упал"
[ ! -d "$TMP/.ai/dry-feature" ] || fail "dry-run создал папку, хотя не должен"

echo "OK: test-ai-init (light, gitignore, идемпотентность, heavy, dry-run)"
