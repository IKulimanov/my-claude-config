#!/usr/bin/env bash
# Тест ротации журналов в hooks/scripts/lib/common.sh: файл больше порога (CLAUDE_LOG_MAX_MB) переименовывается
# в <name>-<дата>.jsonl перед записью, старый срез не удаляется; файл меньше порога не трогается.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON="$SCRIPT_DIR/../hooks/scripts/lib/common.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

export CLAUDE_LOG_DIR="$TMP/logs" CLAUDE_LOG_MAX_MB=1
mkdir -p "$CLAUDE_LOG_DIR"

# 1) Журнал больше 1 МБ → срез с датой, новая запись уходит в свежий файл.
python3 -c "open('$CLAUDE_LOG_DIR/tools.jsonl', 'w').write('{\"a\":1}\n' * 150000)"
( . "$COMMON"; hook_log tools '{"b":2}' )
[ "$(wc -l < "$CLAUDE_LOG_DIR/tools.jsonl" | tr -d ' ')" = 1 ] || fail "после ротации в tools.jsonl не одна строка"
rotated=$(/bin/ls "$CLAUDE_LOG_DIR" | grep -E '^tools-[0-9]{8}-[0-9]{6}\.jsonl$' || true)
[ -n "$rotated" ] || fail "нет среза tools-<дата>.jsonl: $(/bin/ls "$CLAUDE_LOG_DIR")"
[ "$(wc -l < "$CLAUDE_LOG_DIR/$rotated" | tr -d ' ')" = 150000 ] || fail "срез потерял строки"

# 2) Журнал меньше порога → без ротации, запись дописывается.
python3 -c "open('$CLAUDE_LOG_DIR/prompts.jsonl', 'w').write('{\"a\":1}\n' * 10)"
( . "$COMMON"; hook_log prompts '{"b":2}' )
[ "$(wc -l < "$CLAUDE_LOG_DIR/prompts.jsonl" | tr -d ' ')" = 11 ] || fail "маленький журнал ротирован или запись потеряна"
[ -z "$(/bin/ls "$CLAUDE_LOG_DIR" | grep -E '^prompts-' || true)" ] || fail "маленький журнал получил срез"

echo "OK: test-log-rotate (срез при превышении порога, старые строки целы, маленький журнал не трогается)"
