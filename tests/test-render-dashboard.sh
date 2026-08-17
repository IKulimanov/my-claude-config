#!/usr/bin/env bash
# Smoke-тест рендера дашборда render-dashboard.sh:
#  - в HTML попали оба недельных снапшота и JSON-блоб с id="analytics-data";
#  - есть поддержка тёмной темы (prefers-color-scheme);
#  - выдержка «Эксперимент недели» из последнего отчёта попала в payload;
#  - в JSON-блобе нет сырого "</script" (экранирование не сломано).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER="$SCRIPT_DIR/../scripts/render-dashboard.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

HIST="$TMP/history"; REPORTS="$TMP/reports"; OUT="$TMP/dashboard.html"
mkdir -p "$HIST" "$REPORTS"

mk_snap() { # mk_snap <week> <sessions> <from> <to>
  jq -n --arg w "$1" --argjson s "$2" --arg from "$3" --arg to "$4" '{
    schema_version: 1, week: $w, range: {from: $from, to: $to},
    generated_at: "2026-07-11T09:00:00Z",
    sessions: {total: $s, by_project: {alpha: $s}},
    daily_sessions: {($from[0:10]): $s}, active_days: 1,
    peak: {date: $from[0:10], sessions: $s},
    tokens: {input: 100, output: 2000, cache_read: 50000, cache_write: 300, turns: 40,
             by_project_top: [{project: "alpha", input: 100, output: 2000}]},
    models: {"claude-sonnet-4-6": $s},
    tools: {top: [{name: "Bash", count: 10}], failures_total: 1,
            failures_by_tool: [{name: "Edit", count: 1}]},
    skills: {top: [{name: "review", count: 2}]},
    slash_commands: {top: [{name: "/plan", count: 3}]},
    subagents: {top: [{name: "java-reviewer", count: 1}]},
    prompts: {count: 20, mean_length: 300, median_length: 150, slash_pct: 25, cyrillic_pct: 75},
    plan_mode: {exit_plan_mode_count: 2},
    tdd: {test_edits: 5, prod_edits: 10, test_runs: 4},
    blocks: {by_kind: {}, total: 0},
    friction: {total: 1, by_keyword: {"не так": 1}},
    enrichment: {ccusage: {available: false, reason: "disabled"}}
  }' > "$HIST/$1.json"
}

mk_snap "2026-W27" 10 "2026-06-27T00:00:00Z" "2026-07-04T00:00:00Z"
mk_snap "2026-W28" 20 "2026-07-04T00:00:00Z" "2026-07-11T00:00:00Z"

cat > "$REPORTS/2026-W28.md" <<'EOF'
# Недельный обзор 2026-W28

## Сводка недели
Всё хорошо.

## Красные флаги
Слишком много марафонских сессий </script> опасный текст.

## Эксперимент недели
Провести один день без ИИ и записать наблюдения.

## Health report
Данные свежие.
EOF

"$RENDER" --history "$HIST" --reports "$REPORTS" --out "$OUT" || fail "render aborted"
[ -f "$OUT" ] || fail "dashboard.html не создан"

grep -q '2026-W27' "$OUT" || fail "нет недели 2026-W27"
grep -q '2026-W28' "$OUT" || fail "нет недели 2026-W28"
grep -q 'id="analytics-data"' "$OUT" || fail "нет JSON-блоба analytics-data"
grep -q 'prefers-color-scheme' "$OUT" || fail "нет тёмной темы"
grep -q 'Провести один день без ИИ' "$OUT" || fail "выдержка эксперимента не попала"

# Экранирование: внутри JSON-блоба не должно быть сырого "</script"
blob=$(sed -n '/id="analytics-data"/,/<\/script>/p' "$OUT" | sed '1d;$d')
printf '%s' "$blob" | grep -q '</script' && fail "сырой </script в JSON-блобе"

# Блоб — валидный JSON (после снятия экранирования <\/)
printf '%s' "$blob" | sed 's;<\\/;</;g' | jq -e . >/dev/null || fail "JSON-блоб невалиден"

echo "OK: test-render-dashboard (payload, темы, выдержка отчёта, экранирование)"
