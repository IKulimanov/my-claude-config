#!/usr/bin/env bash
# Тест ai-init.sh: каталог задачи .claude/tasks/<ключ>/ по имени ветки (Jira-ID, иначе имя без типового
# префикса), подпапка agent/, номера для доработок (--new), явное имя, перенос старого .ai/,
# .gitignore проекта не трогает, dry-run ничего не создаёт.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_INIT="$SCRIPT_DIR/../scripts/helpers/ai-init.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
TMP=$(cd "$TMP" && pwd -P)   # git печатает физический путь (/private/var/…), сравниваем с таким же

fail() { echo "FAIL: $1" >&2; exit 1; }

new_repo() {   # <каталог> <ветка>
  git init -q -b "$2" "$1"
  git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

# 1) Рабочая ветка с Jira-ID: ключ = ID, создаётся <ключ>/agent/, путь — последняя строка stdout,
#    .gitignore проекта не трогаем.
REPO="$TMP/work"; new_repo "$REPO" feature/ORSP-1234-export-csv
cd "$REPO"
out=$("$AI_INIT") || fail "ai-init упал"
dir=$(printf '%s\n' "$out" | tail -1)
[ "$dir" = "$REPO/.claude/tasks/ORSP-1234" ] || fail "ключ по Jira-ID: '$dir'"
[ -d "$dir/agent" ] || fail "нет подпапки agent/"
[ ! -e "$REPO/.gitignore" ] || fail ".gitignore проекта тронут"

# 2) Повтор — тот же каталог; --new — следующий номер; без флага — последний существующий.
[ "$("$AI_INIT" | tail -1)" = "$dir" ] || fail "повтор дал другой каталог"
[ "$("$AI_INIT" --new | tail -1)" = "$REPO/.claude/tasks/ORSP-1234-2" ] || fail "--new не дал -2"
[ "$("$AI_INIT" --new | tail -1)" = "$REPO/.claude/tasks/ORSP-1234-3" ] || fail "--new не дал -3"
[ "$("$AI_INIT" | tail -1)" = "$REPO/.claude/tasks/ORSP-1234-3" ] || fail "без флага не последний каталог"
[ -d "$REPO/.claude/tasks/ORSP-1234-3/agent" ] || fail "у доработки нет agent/"

# 3) Личная ветка без ID: типовой префикс срезан, слэши → дефис.
REPO2="$TMP/personal"; new_repo "$REPO2" feature/export-csv
cd "$REPO2"
[ "$("$AI_INIT" | tail -1)" = "$REPO2/.claude/tasks/export-csv" ] || fail "ключ личной ветки"
git -C "$REPO2" checkout -q -b refactor/config-2026-09
[ "$("$AI_INIT" | tail -1)" = "$REPO2/.claude/tasks/config-2026-09" ] || fail "префикс refactor/ не срезан"
git -C "$REPO2" checkout -q -b release/1.2
[ "$("$AI_INIT" | tail -1)" = "$REPO2/.claude/tasks/release-1.2" ] || fail "release/ не срезается, слэш → дефис"

# 4) Явное имя: ветка коллеги для /review-mr и произвольный текст.
[ "$("$AI_INIT" feature/ORSP-2000-fix | tail -1)" = "$REPO2/.claude/tasks/ORSP-2000" ] || fail "явное имя с ID"
[ "$("$AI_INIT" 'My Feature' | tail -1)" = "$REPO2/.claude/tasks/My-Feature" ] || fail "явное имя без ID"
[ "$("$AI_INIT" --new 'My Feature' | tail -1)" = "$REPO2/.claude/tasks/My-Feature-2" ] || fail "--new с явным именем"

# 5) Старый .ai/ (не в git) переезжает в .claude/tasks/; занятое имя остаётся на месте с предупреждением.
REPO3="$TMP/legacy"; new_repo "$REPO3" feature/ORSP-1-x
mkdir -p "$REPO3/.ai/old-feature" "$REPO3/.ai/big/a" "$REPO3/.ai/busy" "$REPO3/.claude/tasks/busy"
echo plan > "$REPO3/.ai/old-feature/plan.md"
echo plan > "$REPO3/.ai/big/a/plan.md"
echo old  > "$REPO3/.ai/busy/plan.md"
cd "$REPO3"
"$AI_INIT" >/dev/null 2>"$TMP/err" || fail "ai-init с legacy упал"
[ -f "$REPO3/.claude/tasks/old-feature/plan.md" ] || fail "old-feature не переехал"
[ -f "$REPO3/.claude/tasks/big/a/plan.md" ] || fail "big/a не переехал"
[ -f "$REPO3/.ai/busy/plan.md" ] || fail "занятое имя перемещено или удалено"
[ ! -e "$REPO3/.claude/tasks/busy/plan.md" ] || fail "занятый каталог перезаписан"
grep -q busy "$TMP/err" || fail "нет предупреждения о занятом имени"

# 6) Пустой после переезда .ai/ убирается; отслеживаемый git .ai/ не трогаем.
REPO4="$TMP/clean"; new_repo "$REPO4" feature/ORSP-2-x
mkdir -p "$REPO4/.ai/only"; echo x > "$REPO4/.ai/only/plan.md"
cd "$REPO4"; "$AI_INIT" >/dev/null 2>&1 || fail "ai-init упал на чистом переезде"
[ -f "$REPO4/.claude/tasks/only/plan.md" ] || fail "only не переехал"
[ ! -e "$REPO4/.ai" ] || fail "пустой .ai/ остался"

REPO5="$TMP/tracked"; new_repo "$REPO5" feature/ORSP-3-x
mkdir -p "$REPO5/.ai/kept"; echo x > "$REPO5/.ai/kept/plan.md"
git -C "$REPO5" add .ai && git -C "$REPO5" -c user.name=t -c user.email=t@t commit -q -m ai
cd "$REPO5"; "$AI_INIT" >/dev/null 2>&1 || fail "ai-init упал на отслеживаемом .ai"
[ -f "$REPO5/.ai/kept/plan.md" ] || fail "отслеживаемый .ai/ перемещён"

# 7) Dry-run печатает путь и ничего не создаёт; вне git — каталог от cwd с явным именем.
REPO6="$TMP/dry"; new_repo "$REPO6" feature/ORSP-4-x
cd "$REPO6"
[ "$("$AI_INIT" -n | tail -1)" = "$REPO6/.claude/tasks/ORSP-4" ] || fail "dry-run печатает не тот путь"
[ ! -d "$REPO6/.claude" ] || fail "dry-run создал каталог"
mkdir -p "$TMP/plain"; cd "$TMP/plain"
[ "$("$AI_INIT" notes | tail -1)" = "$TMP/plain/.claude/tasks/notes" ] || fail "вне git с явным именем"

echo "OK: test-ai-init (ключ по ветке, --new, явное имя, перенос .ai/, tracked .ai/ цел, dry-run)"
