#!/usr/bin/env bash
# Тест компонентов config и workspace в setup-global.sh: symlink ~/.claude/my-claude-config на репозиторий,
# ~/.claude/workspace.md из workspace.conf (каталоги создаются, конвенция и плагин подписаны), строка
# @import workspace.md в управляемом блоке CLAUDE.md, workspace.conf создаётся из примера, dry-run чист,
# status показывает оба компонента, uninstall убирает symlink и workspace.md, но не каталоги.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
SCRIPT="$ROOT/scripts/setup-global.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

export HOME="$TMP/home" XDG_CONFIG_HOME="$TMP/xdg" CLAUDE_HOME="$TMP/claude"
mkdir -p "$HOME"

# Минимальный «репозиторий конфига»: пример, свой workspace.conf и одно правило.
CFG="$TMP/cfg"; mkdir -p "$CFG/rules"
cp "$ROOT/workspace.conf.example" "$CFG/"
echo "# правило" > "$CFG/rules/01-test.md"
cat > "$CFG/workspace.conf" <<EOF
WORK_ROOT="$HOME/w"
PERSONAL_ROOT="$HOME/p"
CONVENTION_DIR="$HOME/w/conv/docs"
CONVENTION_PLUGIN=""
REVIEWS_DIR="$HOME/reviews"
EOF

# 1) Установка: symlink, workspace.md, каталоги, import в CLAUDE.md.
"$SCRIPT" install --apply --config-dir "$CFG" --components config,workspace,claude-md >/dev/null
[ "$(readlink "$CLAUDE_HOME/my-claude-config")" = "$CFG" ] || fail "symlink my-claude-config не на репозиторий"
WS="$CLAUDE_HOME/workspace.md"
[ -f "$WS" ] || fail "нет workspace.md"
grep -qF "$HOME/w" "$WS" || fail "workspace.md без WORK_ROOT"
grep -qF "$HOME/p" "$WS" || fail "workspace.md без PERSONAL_ROOT"
grep -qF "$HOME/w/conv/docs" "$WS" || fail "workspace.md без пути конвенции"
grep -qF "$HOME/reviews" "$WS" || fail "workspace.md без каталога ревью"
grep -q 'плагина конвенции: не задан' "$WS" || fail "пустой CONVENTION_PLUGIN не подписан как «не задан»"
[ -d "$HOME/w" ] && [ -d "$HOME/p" ] && [ -d "$HOME/reviews" ] || fail "каталоги work/personal/reviews не созданы"
grep -qF "@$WS" "$CLAUDE_HOME/CLAUDE.md" || fail "нет @import workspace.md в CLAUDE.md"
grep -qF "@$CFG/rules/01-test.md" "$CLAUDE_HOME/CLAUDE.md" || fail "правила не импортированы"

# 2) Повтор идемпотентен.
"$SCRIPT" install --apply --config-dir "$CFG" --components config,workspace,claude-md >/dev/null
[ "$(readlink "$CLAUDE_HOME/my-claude-config")" = "$CFG" ] || fail "повтор сломал symlink"
[ "$(grep -cF "@$WS" "$CLAUDE_HOME/CLAUDE.md")" = 1 ] || fail "дубль импорта workspace.md"

# 3) status показывает оба компонента.
st=$("$SCRIPT" status --config-dir "$CFG")
grep -Eq '^config +linked-ok' <<<"$st" || fail "status: config не linked-ok"
grep -Eq '^workspace +present' <<<"$st" || fail "status: workspace не present"

# 4) Нет workspace.conf → создаётся из примера, значения по умолчанию.
CFG2="$TMP/cfg2"; mkdir -p "$CFG2"; cp "$ROOT/workspace.conf.example" "$CFG2/"
CLAUDE_HOME="$TMP/claude2" "$SCRIPT" install --apply --config-dir "$CFG2" --components workspace >/dev/null
[ -f "$CFG2/workspace.conf" ] || fail "workspace.conf не создан из примера"
grep -qF "$HOME/dev/work" "$TMP/claude2/workspace.md" || fail "значение по умолчанию WORK_ROOT не применилось"

# 5) Dry-run ничего не создаёт.
CFG3="$TMP/cfg3"; mkdir -p "$CFG3"; cp "$ROOT/workspace.conf.example" "$CFG3/"
CLAUDE_HOME="$TMP/claude3" "$SCRIPT" install --config-dir "$CFG3" --components config,workspace >/dev/null
[ ! -e "$TMP/claude3/workspace.md" ] && [ ! -e "$TMP/claude3/my-claude-config" ] && [ ! -e "$CFG3/workspace.conf" ] \
  || fail "dry-run что-то создал"

# 6) uninstall: symlink и workspace.md убраны, каталоги целы.
"$SCRIPT" uninstall --apply --config-dir "$CFG" >/dev/null
[ ! -e "$CLAUDE_HOME/my-claude-config" ] || fail "uninstall оставил symlink"
[ ! -e "$WS" ] || fail "uninstall оставил workspace.md"
[ -d "$HOME/w" ] || fail "uninstall удалил каталог work"
st=$("$SCRIPT" status --config-dir "$CFG")
grep -Eq '^config +missing' <<<"$st" || fail "status после uninstall: config не missing"

echo "OK: test-setup-workspace (symlink, workspace.md, import, пример, dry-run, status, uninstall)"
