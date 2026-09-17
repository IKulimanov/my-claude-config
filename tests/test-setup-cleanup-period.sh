#!/usr/bin/env bash
# Тест: setup-global.sh install --apply ставит cleanupPeriodDays=90 в settings.json, если ключа нет,
# и не трогает уже заданное значение. Без него транскрипты старше 30 дней удаляются, а только в них
# видны модели субагентов и загрузки скилов для месячного аудита.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/../scripts/setup-global.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Ключа нет — появляется 90.
HOME1="$TMP/home1"; mkdir -p "$HOME1"
printf '{\n  "model": "opus[1m]"\n}\n' > "$HOME1/settings.json"
CLAUDE_HOME="$HOME1" "$SCRIPT" install --apply --components output-styles >/dev/null
[ "$(jq -r '.cleanupPeriodDays' "$HOME1/settings.json")" = "90" ] || fail "cleanupPeriodDays не выставлен"
[ "$(jq -r '.model' "$HOME1/settings.json")" = "opus[1m]" ] || fail "прочие ключи потеряны"

# 2. Ключ задан пользователем — остаётся.
HOME2="$TMP/home2"; mkdir -p "$HOME2"
printf '{\n  "cleanupPeriodDays": 30\n}\n' > "$HOME2/settings.json"
CLAUDE_HOME="$HOME2" "$SCRIPT" install --apply --components output-styles >/dev/null
[ "$(jq -r '.cleanupPeriodDays' "$HOME2/settings.json")" = "30" ] || fail "пользовательское значение перезаписано"

# 3. Dry-run ничего не пишет.
HOME3="$TMP/home3"; mkdir -p "$HOME3"
CLAUDE_HOME="$HOME3" "$SCRIPT" install --components output-styles >/dev/null
[ ! -f "$HOME3/settings.json" ] || fail "dry-run создал settings.json"

echo "OK: test-setup-cleanup-period (90 по умолчанию, пользовательское значение сохранено, dry-run чист)"
