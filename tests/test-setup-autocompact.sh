#!/usr/bin/env bash
# Тест: setup-global.sh install --apply ставит autoCompactWindow=300000 в settings.json, если ключа нет,
# и не трогает уже заданное значение. Без него модели с окном 1M сжимают контекст около 967 тыс. токенов:
# главный поток дорастал до 950 тыс., и каждый шаг перечитывал этот контекст из кэша.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/setup-global.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Ключа нет — появляется 300000, прочие ключи на месте.
HOME1="$TMP/home1"; mkdir -p "$HOME1"
printf '{\n  "model": "opus[1m]"\n}\n' > "$HOME1/settings.json"
CLAUDE_HOME="$HOME1" "$SCRIPT" install --apply --components output-styles >/dev/null
[ "$(jq -r '.autoCompactWindow' "$HOME1/settings.json")" = "300000" ] || fail "autoCompactWindow не выставлен"
[ "$(jq -r '.model' "$HOME1/settings.json")" = "opus[1m]" ] || fail "прочие ключи потеряны"

# 2. Ключ задан пользователем — остаётся.
HOME2="$TMP/home2"; mkdir -p "$HOME2"
printf '{\n  "autoCompactWindow": 500000\n}\n' > "$HOME2/settings.json"
CLAUDE_HOME="$HOME2" "$SCRIPT" install --apply --components output-styles >/dev/null
[ "$(jq -r '.autoCompactWindow' "$HOME2/settings.json")" = "500000" ] || fail "пользовательское значение перезаписано"

# 3. Dry-run ничего не пишет; status показывает ключ.
HOME3="$TMP/home3"; mkdir -p "$HOME3"
CLAUDE_HOME="$HOME3" "$SCRIPT" install --components output-styles >/dev/null
[ ! -f "$HOME3/settings.json" ] || fail "dry-run создал settings.json"
STATUS=$(CLAUDE_HOME="$HOME1" "$SCRIPT" status)
printf '%s\n' "$STATUS" | grep -q 'autoCompact.*300000' || fail "status не показывает autoCompactWindow"

echo "OK: test-setup-autocompact (300000 по умолчанию, пользовательское значение сохранено, dry-run чист)"
