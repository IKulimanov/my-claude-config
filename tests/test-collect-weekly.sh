#!/usr/bin/env bash
# Тесты коллектора недельных снапшотов collect-weekly.sh на фикстурах:
#  - границы окна Сб–Пт UTC: запись следующей субботы не попадает в прошлое окно;
#  - подсчёты: sessions, tools (только phase=pre), skills, slash, tdd, plan_mode,
#    friction, blocks (в т.ч. старый формат без project), tokens, models, prompts;
#  - битая строка лога пропускается, а не роняет сбор;
#  - идемпотентность: повторный запуск не трогает файл соседней недели;
#  - --backfill: создаёт все окна, существующие не перезаписывает, --force — перезаписывает.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECT="$SCRIPT_DIR/../scripts/collect-weekly.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

LOGS="$TMP/logs"; OUT="$TMP/out"
mkdir -p "$LOGS"

# --- Фикстуры. Окно A: Сб 2026-05-16 → Пт 2026-05-22 (= 2026-W21). ---
# --- Окно B: Сб 2026-05-23 → Пт 2026-05-29 (= 2026-W22). ---

{
  echo '{"ts":"2026-05-16T08:00:00Z","event":"SessionStart","session":"s1","project":"alpha"}'
  echo '{"ts":"2026-05-17T09:00:00Z","event":"SessionStart","session":"s2","project":"alpha"}'
  echo '{"ts":"2026-05-22T23:59:59Z","event":"SessionStart","session":"s3","project":"beta"}'
  echo 'BROKEN LINE NOT JSON'
  echo '{"ts":"2026-05-23T00:00:00Z","event":"SessionStart","session":"s4","project":"beta"}'
  echo '{"ts":"2026-05-25T10:00:00Z","event":"SessionEnd","session":"s4","project":"beta"}'
} > "$LOGS/sessions.jsonl"

{
  echo '{"ts":"2026-05-16T10:00:00Z","phase":"pre","tool":"Bash","tool_use_id":"t1","project":"alpha","input":{"command":"ls"}}'
  echo '{"ts":"2026-05-16T10:00:01Z","phase":"post","tool":"Bash","tool_use_id":"t1","project":"alpha","input":{"command":"ls"}}'
  echo '{"ts":"2026-05-16T10:00:02Z","phase":"pre","tool":"Bash","tool_use_id":"t2","project":"alpha","input":{"command":"pwd"}}'
  echo '{"ts":"2026-05-16T10:00:03Z","phase":"post","tool":"Bash","tool_use_id":"t2","project":"alpha","input":{"command":"pwd"}}'
  echo '{"ts":"2026-05-16T10:01:00Z","phase":"pre","tool":"Edit","tool_use_id":"t3","project":"alpha","input":{"file_path":"/p/src/test/java/FooTest.java"}}'
  echo '{"ts":"2026-05-16T10:02:00Z","phase":"pre","tool":"Edit","tool_use_id":"t4","project":"alpha","input":{"file_path":"/p/src/main/App.java"}}'
  echo '{"ts":"2026-05-16T10:03:00Z","phase":"pre","tool":"Write","tool_use_id":"t5","project":"alpha","input":{"file_path":"/p/bar_test.go"}}'
  echo '{"ts":"2026-05-16T10:04:00Z","phase":"pre","tool":"Bash","tool_use_id":"t6","project":"alpha","input":{"command":"mvn -q test"}}'
  echo '{"ts":"2026-05-16T10:05:00Z","phase":"pre","tool":"Bash","tool_use_id":"t7","project":"alpha","input":{"command":"go test ./..."}}'
  echo '{"ts":"2026-05-16T10:06:00Z","phase":"pre","tool":"Skill","tool_use_id":"t8","project":"alpha","input":{"skill":"review"}}'
  echo '{"ts":"2026-05-16T10:07:00Z","phase":"pre","tool":"Skill","tool_use_id":"t9","project":"alpha","input":{"skill":"review"}}'
  echo '{"ts":"2026-05-16T10:08:00Z","phase":"pre","tool":"Skill","tool_use_id":"t10","project":"beta","input":{"skill":"plan"}}'
  echo '{"ts":"2026-05-16T10:09:00Z","phase":"pre","tool":"ExitPlanMode","tool_use_id":"t11","project":"alpha","input":{}}'
  echo '{"ts":"2026-05-16T10:10:00Z","phase":"fail","tool":"Edit","tool_use_id":"t12","project":"alpha","input":{"file_path":"/p/x.java"}}'
  echo '{"ts":"2026-05-24T10:00:00Z","phase":"pre","tool":"Read","tool_use_id":"t13","project":"beta","input":{"file_path":"/p/y.java"}}'
} > "$LOGS/tools.jsonl"

{
  echo '{"ts":"2026-05-16T11:00:00Z","project":"alpha","length":100,"head":"сделай фичу","slash_command":"/feature"}'
  echo '{"ts":"2026-05-17T11:00:00Z","project":"alpha","length":50,"head":"это не работает опять"}'
  echo '{"ts":"2026-05-18T11:00:00Z","project":"beta","length":300,"head":"please fix the build"}'
  echo '{"ts":"2026-05-19T11:00:00Z","project":"beta","length":20,"head":"bad","slash_command":"/Users/ivan/raw.txt"}'
} > "$LOGS/prompts.jsonl"

{
  echo '{"ts":"2026-05-16T12:00:00Z","session":"s1","project":"alpha","input_tokens":100,"output_tokens":200,"cache_read":1000,"cache_write":500,"turns":5,"models":["claude-sonnet-4-6"]}'
  echo '{"ts":"2026-05-17T12:00:00Z","session":"s2","project":"alpha","input_tokens":10,"output_tokens":20,"cache_read":0,"cache_write":0,"turns":2,"models":["claude-opus-4-7","<synthetic>"]}'
  echo '{"ts":"2026-05-22T12:00:00Z","session":"s3","project":"beta","input_tokens":1,"output_tokens":2,"cache_read":3,"cache_write":4,"turns":1,"models":["claude-sonnet-4-6"]}'
  # s5: стопы КУМУЛЯТИВНЫ в рамках сессии (Stop пересуммирует весь транскрипт).
  # Последний стоп до окна: 50/50/5; последний в окне: 70/90/8 → дельта 20/40/3.
  echo '{"ts":"2026-05-15T12:00:00Z","session":"s5","project":"gamma","input_tokens":50,"output_tokens":50,"cache_read":0,"cache_write":0,"turns":5,"models":["claude-opus-4-7"]}'
  echo '{"ts":"2026-05-16T09:00:00Z","session":"s5","project":"gamma","input_tokens":70,"output_tokens":90,"cache_read":0,"cache_write":0,"turns":8,"models":["claude-opus-4-7"]}'
} > "$LOGS/stops.jsonl"

{
  echo '{"ts":"2026-05-16T13:00:00Z","event":"SubagentStart","agent_type":"java-reviewer","project":"alpha"}'
  echo '{"ts":"2026-05-16T13:05:00Z","event":"SubagentStop","agent_type":"java-reviewer","project":"alpha"}'
} > "$LOGS/subagents.jsonl"

{
  # старый формат без project — должен считаться (фильтр только по ts)
  echo '{"ts":"2026-05-18T10:00:00Z","kind":"destructive","session":"s1","cwd":"/x","command":"rm -rf /"}'
  echo '{"ts":"2026-05-18T11:00:00Z","kind":"secret","tool":"Read","session":"s1","cwd":"/x","target":"/x/.env","project":"alpha"}'
} > "$LOGS/blocks.jsonl"

run_collect() {
  CLAUDE_LOG_DIR="$LOGS" COLLECT_NOW="2026-06-01T09:00:00Z" "$COLLECT" --out "$OUT" "$@"
}

# --- 1. Сбор окна A ---
run_collect --week 2026-W21 || fail "collect --week 2026-W21 aborted"
SNAP="$OUT/2026-W21.json"
[ -f "$SNAP" ] || fail "snapshot file missing"
jq -e . "$SNAP" >/dev/null || fail "snapshot is not valid JSON"

# --- 2. Границы окна и sessions ---
[ "$(jq -r '.week' "$SNAP")" = "2026-W21" ] || fail "week id"
[ "$(jq -r '.range.from' "$SNAP")" = "2026-05-16T00:00:00Z" ] || fail "range.from"
[ "$(jq -r '.range.to' "$SNAP")" = "2026-05-23T00:00:00Z" ] || fail "range.to"
[ "$(jq -r '.sessions.total' "$SNAP")" = "3" ] || fail "sessions.total != 3 (граница окна нарушена?)"
[ "$(jq -r '.sessions.by_project.alpha' "$SNAP")" = "2" ] || fail "sessions.by_project.alpha != 2"
[ "$(jq -r '.sessions.by_project.beta' "$SNAP")" = "1" ] || fail "sessions.by_project.beta != 1"
[ "$(jq -r '.active_days' "$SNAP")" = "3" ] || fail "active_days != 3"
[ "$(jq -r '.daily_sessions["2026-05-16"]' "$SNAP")" = "1" ] || fail "daily_sessions[05-16] != 1"

# --- 3. Tools: только phase=pre; failures отдельно ---
[ "$(jq -r '.tools.top[] | select(.name=="Bash") | .count' "$SNAP")" = "4" ] || fail "tools Bash != 4 (post-фаза посчитана?)"
[ "$(jq -r '.tools.failures_total' "$SNAP")" = "1" ] || fail "failures_total != 1"
[ "$(jq -r '.tools.failures_by_tool[] | select(.name=="Edit") | .count' "$SNAP")" = "1" ] || fail "failures Edit != 1"

# --- 4. Skills, slash, subagents ---
[ "$(jq -r '.skills.top[] | select(.name=="review") | .count' "$SNAP")" = "2" ] || fail "skills review != 2"
[ "$(jq -r '.slash_commands.top[] | select(.name=="/feature") | .count' "$SNAP")" = "1" ] || fail "slash /feature != 1"
jq -e '.slash_commands.top[] | select(.name | startswith("/Users"))' "$SNAP" >/dev/null && fail "slash: путь протёк как команда"
[ "$(jq -r '.subagents.top[] | select(.name=="java-reviewer") | .count' "$SNAP")" = "1" ] || fail "subagents java-reviewer != 1"

# --- 5. TDD и plan mode ---
[ "$(jq -r '.tdd.test_edits' "$SNAP")" = "2" ] || fail "tdd.test_edits != 2"
[ "$(jq -r '.tdd.prod_edits' "$SNAP")" = "1" ] || fail "tdd.prod_edits != 1"
[ "$(jq -r '.tdd.test_runs' "$SNAP")" = "2" ] || fail "tdd.test_runs != 2"
[ "$(jq -r '.plan_mode.exit_plan_mode_count' "$SNAP")" = "1" ] || fail "plan_mode != 1"

# --- 6. Prompts и friction ---
[ "$(jq -r '.prompts.count' "$SNAP")" = "4" ] || fail "prompts.count != 4"
[ "$(jq -r '.prompts.median_length' "$SNAP")" = "100" ] || fail "prompts.median != 100"
[ "$(jq -r '.prompts.cyrillic_pct' "$SNAP")" = "50" ] || fail "prompts.cyrillic_pct != 50"
[ "$(jq -r '.prompts.slash_pct' "$SNAP")" = "25" ] || fail "prompts.slash_pct != 25 (валидные slash)"
[ "$(jq -r '.friction.total' "$SNAP")" = "1" ] || fail "friction.total != 1 (промпт считается один раз)"
[ "$(jq -r '.friction.by_keyword["не работает"]' "$SNAP")" = "1" ] || fail 'friction["не работает"] != 1'

# --- 7. Tokens (дельты кумулятивных стопов по сессиям), models, blocks ---
[ "$(jq -r '.tokens.input' "$SNAP")" = "131" ] || fail "tokens.input != 131 (кумулятивные стопы пересуммированы?)"
[ "$(jq -r '.tokens.output' "$SNAP")" = "262" ] || fail "tokens.output != 262"
[ "$(jq -r '.tokens.turns' "$SNAP")" = "11" ] || fail "tokens.turns != 11"
[ "$(jq -r '.tokens.by_project_top[0].project' "$SNAP")" = "alpha" ] || fail "by_project_top[0] != alpha"
[ "$(jq -r '.models["claude-sonnet-4-6"]' "$SNAP")" = "2" ] || fail "models sonnet != 2"
[ "$(jq -r '.models["claude-opus-4-7"]' "$SNAP")" = "2" ] || fail "models opus != 2"
jq -e '.models["<synthetic>"]' "$SNAP" >/dev/null && fail "models: <synthetic> не отфильтрован"
[ "$(jq -r '.blocks.total' "$SNAP")" = "2" ] || fail "blocks.total != 2 (старый формат без project потерян?)"
[ "$(jq -r '.blocks.by_kind.destructive' "$SNAP")" = "1" ] || fail "blocks destructive != 1"

# --- 8. Идемпотентность: файл соседней недели не трогается ---
echo '{"sentinel":true}' > "$OUT/2026-W22.json"
run_collect --week 2026-W21 || fail "повторный сбор упал"
jq -e '.sentinel' "$OUT/2026-W22.json" >/dev/null || fail "сосед 2026-W22.json перезаписан"

# --- 9. Backfill: создаёт окна, существующие пропускает, --force перезаписывает ---
rm -rf "$OUT"
run_collect --backfill || fail "backfill упал"
[ -f "$OUT/2026-W21.json" ] || fail "backfill: нет 2026-W21"
[ -f "$OUT/2026-W22.json" ] || fail "backfill: нет 2026-W22"
# COLLECT_NOW=2026-06-01 (Пн, внутри окна W23) → окно W23 не завершено и не создаётся
[ -f "$OUT/2026-W23.json" ] && fail "backfill: создано незавершённое окно W23"
echo '{"marker":"manual"}' > "$OUT/2026-W21.json"
run_collect --backfill || fail "повторный backfill упал"
[ "$(jq -r '.marker' "$OUT/2026-W21.json")" = "manual" ] || fail "backfill перезаписал существующий снапшот"
run_collect --week 2026-W21 --force || fail "--force упал"
[ "$(jq -r '.week' "$OUT/2026-W21.json")" = "2026-W21" ] || fail "--force не перезаписал снапшот"

# --- 10. Окно B: запись 2026-05-24 попала в W22, а не в W21 ---
[ "$(jq -r '.sessions.total' "$OUT/2026-W22.json")" = "1" ] || fail "W22 sessions != 1"
[ "$(jq -r '.tools.top[] | select(.name=="Read") | .count' "$OUT/2026-W22.json")" = "1" ] || fail "W22 Read != 1"

# --- 11. --print-window: "<prev> <week> <next>", ничего не собирает ---
out=$(run_collect --print-window --week 2026-W22) || fail "--print-window упал"
[ "$out" = "2026-W21 2026-W22 2026-W23" ] || fail "--print-window --week: '$out'"
# без --week — последнее завершённое окно (COLLECT_NOW=2026-06-01 → W22)
out=$(run_collect --print-window) || fail "--print-window (default) упал"
[ "$out" = "2026-W21 2026-W22 2026-W23" ] || fail "--print-window default: '$out'"

echo "OK: test-collect-weekly (окна, подсчёты, идемпотентность, backfill)"
