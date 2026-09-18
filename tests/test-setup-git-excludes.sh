#!/usr/bin/env bash
# Тест: setup-global.sh install --apply --components git-excludes пишет управляемый блок в глобальный
# excludes git (core.excludesFile, иначе ~/.config/git/ignore): .claude/tasks/, .claude/settings.local.json,
# .ai/. Чужие строки сохраняет, повтор не дублирует, git реально игнорирует, status показывает,
# uninstall убирает только блок, dry-run ничего не пишет.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/setup-global.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Домашний каталог подменяем целиком: git читает глобальный конфиг и excludes оттуда.
export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/xdg" CLAUDE_HOME="$TMP/claude"
mkdir -p "$HOME" "$XDG_CONFIG_HOME/git"
F="$XDG_CONFIG_HOME/git/ignore"
printf '**/.DS_Store\n' > "$F"   # строка пользователя

# 1) Блок дописан, строка пользователя цела.
"$SCRIPT" install --apply --components git-excludes >/dev/null
grep -qxF '**/.DS_Store' "$F" || fail "строка пользователя потеряна"
for l in '.claude/tasks/' '.claude/settings.local.json' '.ai/'; do
  grep -qxF "$l" "$F" || fail "нет строки $l"
done
grep -q 'BEGIN my-claude-config (managed)' "$F" || fail "нет маркера блока"

# 2) Повтор — без дублей.
"$SCRIPT" install --apply --components git-excludes >/dev/null
[ "$(grep -cxF '.claude/tasks/' "$F")" = 1 ] || fail "дубль строки после повтора"
[ "$(grep -c 'BEGIN my-claude-config' "$F")" = 1 ] || fail "дубль блока"

# 3) git реально игнорирует пути в любом репозитории; проектный settings.json — нет.
REPO="$TMP/repo"; git init -q "$REPO"
git -C "$REPO" check-ignore -q .claude/tasks/ORSP-1/plan.md || fail "git не игнорирует .claude/tasks/"
git -C "$REPO" check-ignore -q .claude/settings.local.json || fail "git не игнорирует settings.local.json"
git -C "$REPO" check-ignore -q .ai/x/plan.md || fail "git не игнорирует .ai/"
git -C "$REPO" check-ignore -q .claude/settings.json && fail "проектный .claude/settings.json игнорируется"

# 4) status показывает git-excludes (вывод в переменную: grep -q в пайпе даёт SIGPIPE при pipefail).
st=$("$SCRIPT" status)
grep -Eq '^git-excludes +present' <<<"$st" || fail "status не показывает git-excludes present"

# 5) uninstall убирает блок, строку пользователя оставляет.
"$SCRIPT" uninstall --apply >/dev/null
grep -qxF '**/.DS_Store' "$F" || fail "uninstall стёр строку пользователя"
grep -q 'my-claude-config' "$F" && fail "uninstall не убрал блок"
grep -qxF '.claude/tasks/' "$F" && fail "uninstall оставил .claude/tasks/"
st=$("$SCRIPT" status)
grep -Eq '^git-excludes +missing' <<<"$st" || fail "status после uninstall не missing"

# 6) core.excludesFile задан пользователем — пишем туда, с раскрытием ~.
git config --global core.excludesFile '~/my-ignore'
"$SCRIPT" install --apply --components git-excludes >/dev/null
grep -qxF '.claude/tasks/' "$HOME/my-ignore" || fail "не записано в core.excludesFile"
grep -q 'my-claude-config' "$F" && fail "записано в ~/.config, хотя задан core.excludesFile"

# 7) Dry-run ничего не пишет.
rm "$HOME/my-ignore"
"$SCRIPT" install --components git-excludes >/dev/null
[ ! -e "$HOME/my-ignore" ] || fail "dry-run создал файл"

echo "OK: test-setup-git-excludes (блок, идемпотентность, check-ignore, status, uninstall, core.excludesFile, dry-run)"
