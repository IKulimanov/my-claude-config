#!/usr/bin/env bash
# Тесты для hook_log: каждая запись должна попадать в лог как одна строка JSONL,
# даже если payload пришёл многострочным (pretty-printed). Это защищает от
# поломки jq-стрима при частичной/гонке записи.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

export CLAUDE_LOG_DIR="$TMP"
. "$SCRIPT_DIR/../hooks/scripts/lib/common.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1. Многострочный (pretty) payload -> ровно одна строка в файле.
PRETTY=$(jq -n '{ts:"2026-06-23T10:00:00Z", event:"SessionStart", session:"abc"}')
[ "$(printf '%s\n' "$PRETTY" | wc -l | tr -d ' ')" -gt 1 ] || fail "fixture must be multi-line"
hook_log "sessions" "$PRETTY"
lines=$(wc -l < "$TMP/sessions.jsonl" | tr -d ' ')
[ "$lines" -eq 1 ] || fail "expected 1 line for pretty payload, got $lines"

# 2. Записанная строка — валидный компактный JSON с сохранёнными полями.
got_event=$(jq -r '.event' "$TMP/sessions.jsonl")
[ "$got_event" = "SessionStart" ] || fail "field lost after compaction: event=$got_event"

# 3. Несколько записей -> по одной строке каждая, все валидны.
hook_log "sessions" "$(jq -n '{ts:"2026-06-23T10:01:00Z", event:"SessionEnd"}')"
total=$(wc -l < "$TMP/sessions.jsonl" | tr -d ' ')
[ "$total" -eq 2 ] || fail "expected 2 lines after second append, got $total"
jq -e . "$TMP/sessions.jsonl" >/dev/null || fail "log is not valid line-by-line JSON"

echo "OK: test-hook-log ($total records, all single-line)"
