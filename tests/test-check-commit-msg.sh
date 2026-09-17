#!/usr/bin/env bash
# Тест: check-commit-msg.sh — формат первой строки коммита: рабочий проект `JIRA-ID: Глагол …`
# (ID совпадает с веткой; без ID в ветке — `Глагол …`), личный `тип(scope): глагол …`; русский;
# ≤ 72 символа; без трейлеров; heredoc, несколько -m и cd внутри команды распознаются.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/check-commit-msg.sh"

export CLAUDE_WORK_ROOT="$TMP/work"
mkrepo() { git init -q -b "$2" "$1"; git -C "$1" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init; }
WORK_ID="$TMP/work/java/demo-service";  mkrepo "$WORK_ID" "feature/ORSP-2864-localization"
WORK_NOID="$TMP/work/js/cockpit-ui";    mkrepo "$WORK_NOID" "feature/stats-page"
PERS="$TMP/personal/demo-app";          mkrepo "$PERS" "feat/x"

e() { expect_decision "$HOOK" "$1" Bash "$2" "$3"; }

# Рабочий проект, ветка с Jira-ID
e allow "$WORK_ID" 'git commit -m "ORSP-2864: Добавить ретрай отправки в Kafka"'
e allow "$WORK_ID" 'git commit -m "ORSP-2864: добавить ретрай отправки в Kafka"'
e allow "$WORK_ID" 'git commit -q -m "ORSP-2864: Исправить гонку в кэше" -m "Причина: два потока писали одновременно."'
e deny  "$WORK_ID" 'git commit -m "ORSP-2864: add retry"'
e deny  "$WORK_ID" 'git commit -m "Добавить ретрай"'
e deny  "$WORK_ID" 'git commit -m "ORSP-1111: Добавить ретрай"'
e deny  "$WORK_ID" 'git commit -m "ORSP-2864: Добавить ретрай отправки и ещё много всего, чтобы первая строка стала длиннее"'

# Рабочий проект, ветка без Jira-ID
e allow "$WORK_NOID" 'git commit -m "Добавить ленту событий на страницу статистики"'
e allow "$WORK_NOID" 'git commit -m "ORSP-5: Добавить ленту событий"'
e deny  "$WORK_NOID" 'git commit -m "add events feed"'

# Личный проект
e allow "$PERS" 'git commit -m "feat(api): добавить ретрай отправки в Kafka"'
e allow "$PERS" 'git commit -m "docs: обновить README"'
e deny  "$PERS" 'git commit -m "Добавил ретрай"'
e deny  "$PERS" 'git commit -m "feat(api): Add retry"'
e deny  "$PERS" 'git commit -m "ORSP-1: Добавить ретрай"'

# Трейлеры запрещены везде
e deny  "$PERS" 'git commit -m "feat(api): добавить ретрай" -m "Co-Authored-By: Claude <noreply@anthropic.com>"'
HEREDOC_BAD=$'git commit -F - <<\'EOF\'\nfeat(api): добавить ретрай\n\nCo-Authored-By: Claude\nEOF'
e deny  "$PERS" "$HEREDOC_BAD"

# Heredoc и подстановка команды
HEREDOC_OK=$'git commit -F - <<\'EOF\'\nORSP-2864: Исправить гонку в кэше\n\nПричина: два потока писали одновременно.\nEOF'
e allow "$WORK_ID" "$HEREDOC_OK"
SUBST_OK=$'git commit -q -m "$(cat <<\'EOF\'\nfeat(core): убрать дубли\nEOF\n)"'
e allow "$PERS" "$SUBST_OK"

# Без сообщения — редактор недоступен; amend без нового текста — не проверяем
e deny  "$PERS" 'git commit'
e allow "$PERS" 'git commit --amend --no-edit'
e allow "$WORK_ID" "git commit -m \"Merge branch 'feature/x' into staging\""
e allow "$WORK_ID" 'git commit -m "Revert \"ORSP-2864: Добавить ретрай\""'

# Проект определяется по cd внутри команды
e deny  "$PERS" "cd $WORK_ID && git commit -m \"feat(api): добавить ретрай\""
e allow "$PERS" 'git status'

grep -q '"kind":"commit-msg"' "$CLAUDE_LOG_DIR/blocks.jsonl" || fail "нет записи kind=commit-msg"

echo "OK: test-check-commit-msg (work с ID и без, personal, трейлеры, heredoc, cd)"
