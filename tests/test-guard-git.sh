#!/usr/bin/env bash
# Тест: guard-git.sh — deny для push/merge/rebase/pull и защищённых веток, ask для опасных
# локальных операций, allow для обычной работы в ветке; «switch» в пути не считается переключением.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/guard-git.sh"

# Два репозитория: на master и на рабочей ветке — для проверки ветки при commit.
ON_MASTER="$TMP/on-master"
git init -q -b master "$ON_MASTER"
git -C "$ON_MASTER" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
ON_FEATURE="$TMP/on-feature"
git init -q -b feature/ORSP-1-x "$ON_FEATURE"
git -C "$ON_FEATURE" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

e() { expect_decision "$HOOK" "$1" Bash "${3:-$TMP}" "$2"; }

# deny: удалённые операции и история
e deny  'git push origin feature/ORSP-1-x'
e deny  'cd /tmp/x && git push'
e deny  'git push --force-with-lease origin master'
e deny  'git merge staging'
e deny  'git rebase master'
e deny  'git pull --rebase'
e allow 'git merge --abort'
e allow 'git rebase --abort'
e allow 'git merge-base --is-ancestor a b'

# deny: защищённые ветки
e deny  'git checkout master'
e deny  'git switch staging'
e deny  'git checkout main && git status'
e allow 'git checkout -b feature/ORSP-2-y'
e allow 'git checkout feature/ORSP-1-x'
e deny  'git commit -m "ORSP-1: Добавить"' "$ON_MASTER"
e allow 'git commit -m "ORSP-1: Добавить"' "$ON_FEATURE"
e deny  'git commit --no-verify -m x' "$ON_FEATURE"
e deny  'git commit -n -m x' "$ON_FEATURE"

# ask: опасные локальные операции
e ask   'git commit --amend --no-edit' "$ON_FEATURE"
e ask   'git reset --hard HEAD~1'
e ask   'git clean -fd'
e ask   'git branch -D feature/old'
e ask   'git stash drop'
e ask   'git checkout -- src/Main.java'
e ask   'git checkout staging -- helm/values.yml'
e ask   'git restore src/Main.java'
e allow 'git restore --staged src/Main.java'

# allow: обычная работа
e allow 'git status --short'
e allow 'git diff master...HEAD'
e allow 'git fetch origin'
e allow 'git add -A && git stash'
e allow 'git -C /Users/x/dev/switch-service status'
e allow 'echo git push'
e allow 'mvn -q test'

[ -f "$CLAUDE_LOG_DIR/blocks.jsonl" ] || fail "blocks.jsonl не создан"
grep -q '"kind":"git"' "$CLAUDE_LOG_DIR/blocks.jsonl" || fail "нет записи kind=git"

echo "OK: test-guard-git (deny/ask/allow, ветка при commit, -C путь)"
