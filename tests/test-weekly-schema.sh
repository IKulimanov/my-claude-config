#!/usr/bin/env bash
# Контракт схемы недельного снапшота (schema_version 1).
# Дашборд и weekly-review-prompt.md зависят от этих полей — тест фиксирует
# обязательные ключи и их jq-типы, чтобы изменение схемы было осознанным.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$SCRIPT_DIR/../scripts/collect-weekly.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

LOGS="$TMP/logs"; OUT="$TMP/out"
mkdir -p "$LOGS"

# Минимальные фикстуры: по одной записи в окне 2026-W21, часть файлов пустая.
echo '{"ts":"2026-05-16T08:00:00Z","event":"SessionStart","session":"s1","project":"p"}' > "$LOGS/sessions.jsonl"
echo '{"ts":"2026-05-16T10:00:00Z","phase":"pre","tool":"Bash","tool_use_id":"t1","project":"p","input":{"command":"ls"}}' > "$LOGS/tools.jsonl"
: > "$LOGS/prompts.jsonl"
: > "$LOGS/stops.jsonl"
: > "$LOGS/subagents.jsonl"
: > "$LOGS/blocks.jsonl"

CLAUDE_LOG_DIR="$LOGS" COLLECT_NOW="2026-06-01T09:00:00Z" "$COLLECT" --out "$OUT" --week 2026-W21 \
  || fail "collect aborted"
SNAP="$OUT/2026-W21.json"

check() { # check <jq-выражение> <описание>
  jq -e "$1" "$SNAP" >/dev/null || fail "$2 ($1)"
}

check '.schema_version == 1'                              "schema_version"
check '.week | test("^[0-9]{4}-W[0-9]{2}$")'              "week формат"
check '.range.from < .range.to'                           "range from<to"
check '.generated_at | type == "string"'                  "generated_at"
check '.sessions.total | type == "number"'                "sessions.total"
check '.sessions.by_project | type == "object"'           "sessions.by_project"
check '.daily_sessions | type == "object"'                "daily_sessions"
check '.active_days | type == "number"'                   "active_days"
check '.peak | type == "object"'                          "peak"
check '.tokens | (.input, .output, .cache_read, .cache_write, .turns) | type == "number"' "tokens числа"
check '.tokens.by_project_top | type == "array"'          "tokens.by_project_top"
check '.models | type == "object"'                        "models"
check '.tools.top | type == "array"'                      "tools.top"
check '.tools.failures_total | type == "number"'          "tools.failures_total"
check '.tools.failures_by_tool | type == "array"'         "tools.failures_by_tool"
check '.skills.top | type == "array"'                     "skills.top"
check '.slash_commands.top | type == "array"'             "slash_commands.top"
check '.subagents.top | type == "array"'                  "subagents.top"
check '.prompts | (.count, .mean_length, .median_length, .slash_pct, .cyrillic_pct) | type == "number"' "prompts числа"
check '.plan_mode.exit_plan_mode_count | type == "number"' "plan_mode"
check '.tdd | (.test_edits, .prod_edits, .test_runs) | type == "number"' "tdd числа"
check '.blocks.by_kind | type == "object"'                "blocks.by_kind"
check '.blocks.total | type == "number"'                  "blocks.total"
check '.friction.total | type == "number"'                "friction.total"
check '.friction.by_keyword | type == "object"'           "friction.by_keyword"
check '.enrichment.ccusage.available | type == "boolean"' "enrichment.ccusage"

echo "OK: test-weekly-schema (обязательные поля и типы schema_version=1)"
