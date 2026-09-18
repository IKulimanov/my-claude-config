#!/usr/bin/env bash
# Тест: check-commit-msg.sh берёт каталог рабочих проектов из workspace.conf (CLAUDE_WORKSPACE_CONF задаёт
# файл для теста), а не из зашитого ~/dev/work; без конфига — значение по умолчанию $HOME/dev/work.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/check-commit-msg.sh"

unset CLAUDE_WORK_ROOT
export HOME="$TMP/home"
REPO="$TMP/w/proj"
git init -q -b feature/ORSP-1-x "$REPO"
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

# 1) WORK_ROOT из workspace.conf: репозиторий под ним — рабочий, нужен Jira-ID из ветки.
printf 'WORK_ROOT="%s"\n' "$TMP/w" > "$TMP/ws.conf"
export CLAUDE_WORKSPACE_CONF="$TMP/ws.conf"
expect_decision "$HOOK" deny  Bash "$REPO" 'git commit -m "feat(x): добавить что-то"'
expect_decision "$HOOK" allow Bash "$REPO" 'git commit -m "ORSP-1: Добавить что-то"'

# 2) Конфига нет → по умолчанию $HOME/dev/work; наш репозиторий не под ним — личный формат.
export CLAUDE_WORKSPACE_CONF="$TMP/absent.conf"
expect_decision "$HOOK" allow Bash "$REPO" 'git commit -m "feat(x): добавить что-то"'
expect_decision "$HOOK" deny  Bash "$REPO" 'git commit -m "Что-то без типа"'

echo "OK: test-check-commit-msg-workspace (WORK_ROOT из workspace.conf, по умолчанию \$HOME/dev/work)"
