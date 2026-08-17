#!/usr/bin/env bash
# Собирает недельный снапшот использования Claude Code из ~/.claude/logs/*.jsonl
# в analytics/history/<неделя>.json (schema_version 1).
#
# Конвенция окна: суббота 00:00 UTC → пятница 23:59:59 UTC. Окна тайлятся без
# щелей и перекрытий — каждая строка лога принадлежит ровно одному снапшоту.
# Id снапшота = ISO-неделя (%G-W%V) пятницы окна. Якорь — первая суббота
# с логами: 2026-05-16.
#
# Использование:
#   collect-weekly.sh                    # последнее завершённое окно
#   collect-weekly.sh --week 2026-W28    # конкретное окно (пересобирает свой файл)
#   collect-weekly.sh --backfill         # все завершённые окна; существующие пропускает
#   collect-weekly.sh --backfill --force # пересобрать всё
#   collect-weekly.sh --out DIR          # каталог истории (default: <repo>/analytics/history)
#   collect-weekly.sh --ccusage          # обогащение стоимостью через npx ccusage (опционально)
#
# Для тестов: CLAUDE_LOG_DIR — каталог логов, COLLECT_NOW — «текущий момент» (ISO UTC).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/usage-lib.sh
. "$SCRIPT_DIR/lib/usage-lib.sh"

REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$(usage_log_dir)"
ANCHOR_ISO="2026-05-16T00:00:00Z"
WEEK_SECONDS=$((7 * 86400))

command -v jq >/dev/null 2>&1 || { echo "jq не найден — установи: brew install jq" >&2; exit 1; }

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

MODE="single"
WEEK=""
FORCE=0
CCUSAGE=0
PRINT_WINDOW=0
OUT_DIR="$REPO_ROOT/analytics/history"

while [ $# -gt 0 ]; do
  case "$1" in
    --week)         WEEK="$2"; shift 2 ;;
    --backfill)     MODE="backfill"; shift ;;
    --force)        FORCE=1; shift ;;
    --out)          OUT_DIR="$2"; shift 2 ;;
    --ccusage)      CCUSAGE=1; shift ;;
    --print-window) PRINT_WINDOW=1; shift ;;
    -h|--help)      usage; exit 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2; usage >&2; exit 1 ;;
  esac
done

[ -d "$LOG_DIR" ] || { echo "Нет логов в $LOG_DIR" >&2; exit 1; }

# --- Дата-хелперы (BSD date на macOS, GNU как fallback) ---

epoch_from_iso() {
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null \
    || date -u -d "$1" +%s
}

fmt_from_epoch() {
  date -u -r "$1" +"$2" 2>/dev/null \
    || date -u -d "@$1" +"$2"
}

ANCHOR_EPOCH=$(epoch_from_iso "$ANCHOR_ISO")
NOW_EPOCH=$(epoch_from_iso "${COLLECT_NOW:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}")

# Id окна по его началу: ISO-неделя пятницы (start + 6 дней).
week_id_of() {
  fmt_from_epoch $(($1 + 6 * 86400)) "%G-W%V"
}

# Индекс последнего ЗАВЕРШЁННОГО окна (окно, содержащее now, ещё идёт).
last_completed_index() {
  local cur=$(((NOW_EPOCH - ANCHOR_EPOCH) / WEEK_SECONDS))
  echo $((cur - 1))
}

# Начало окна по id недели: шагаем от якоря, пока id не совпадёт.
resolve_week_start() {
  local want="$1" i start
  for i in $(seq 0 520); do
    start=$((ANCHOR_EPOCH + i * WEEK_SECONDS))
    if [ "$(week_id_of "$start")" = "$want" ]; then
      echo "$start"; return 0
    fi
    [ "$start" -gt $((NOW_EPOCH + WEEK_SECONDS)) ] && break
  done
  echo "Не удалось разрешить неделю '$want' (якорь $ANCHOR_ISO)" >&2
  return 1
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Обогащение стоимостью через ccusage. Никогда не роняет сбор: любой сбой
# (нет npx, нет сети, таймаут, неожиданный вывод) -> {"available":false,...}.
ccusage_enrich() {
  local from_epoch="$1" to_epoch="$2" since_d until_d out rc pid killer
  if [ "$CCUSAGE" -ne 1 ]; then
    echo '{"available":false,"reason":"disabled"}'; return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    echo '{"available":false,"reason":"npx not found"}'; return 0
  fi
  since_d=$(fmt_from_epoch "$from_epoch" "%Y%m%d")
  until_d=$(fmt_from_epoch $((to_epoch - 86400)) "%Y%m%d")
  out="$WORK/ccusage.json"
  ( npx --yes ccusage@latest daily --json --since "$since_d" --until "$until_d" > "$out" 2>/dev/null ) &
  pid=$!
  ( sleep 90; kill "$pid" 2>/dev/null ) &
  killer=$!
  if wait "$pid" 2>/dev/null; then rc=0; else rc=1; fi
  { kill "$killer" && wait "$killer"; } 2>/dev/null || true
  if [ "$rc" -ne 0 ] || ! jq -e . "$out" >/dev/null 2>&1; then
    echo '{"available":false,"reason":"ccusage failed or timed out"}'; return 0
  fi
  jq -c '{available: true,
          total_cost_usd: ((.totals.totalCost // ([.daily[]?.totalCost] | add)) // 0)}' "$out" 2>/dev/null \
    || echo '{"available":false,"reason":"unexpected ccusage output"}'
}

# Сбор одного окна: фильтруем каждый лог по [from, to), агрегируем jq-проходами
# и собираем снапшот атомарно (tmp -> mv).
collect_window() {
  local week_id="$1" start_epoch="$2"
  local from_iso to_iso gen_ts out_file tmp_file
  from_iso=$(fmt_from_epoch "$start_epoch" "%Y-%m-%dT%H:%M:%SZ")
  to_iso=$(fmt_from_epoch $((start_epoch + WEEK_SECONDS)) "%Y-%m-%dT%H:%M:%SZ")
  gen_ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  out_file="$OUT_DIR/$week_id.json"

  usage_filter_range "$LOG_DIR/sessions.jsonl"  "$from_iso" "$to_iso" > "$WORK/sessions.raw"
  usage_filter_range "$LOG_DIR/tools.jsonl"     "$from_iso" "$to_iso" > "$WORK/tools.raw"
  usage_filter_range "$LOG_DIR/prompts.jsonl"   "$from_iso" "$to_iso" > "$WORK/prompts.raw"
  usage_filter_range "$LOG_DIR/subagents.jsonl" "$from_iso" "$to_iso" > "$WORK/subagents.raw"
  # blocks.jsonl: старые записи не имеют project — фильтруем только по ts.
  usage_filter_range "$LOG_DIR/blocks.jsonl"    "$from_iso" "$to_iso" > "$WORK/blocks.raw"
  # stops.jsonl НЕ фильтруем по окну: строки кумулятивны в рамках сессии
  # (каждый Stop пересуммирует весь транскрипт), поэтому нужны и стопы ДО окна —
  # токены недели считаются как дельта. Файл маленький, слурпается целиком.
  if [ -f "$LOG_DIR/stops.jsonl" ]; then
    jq -cR 'fromjson? | select(.ts != null)' "$LOG_DIR/stops.jsonl" > "$WORK/stops.raw"
  else
    : > "$WORK/stops.raw"
  fi

  jq -s '
    [.[] | select(.event=="SessionStart")] as $st
    | {
        sessions: {
          total: ($st | length),
          by_project: ($st | group_by(.project // "?")
                           | map({key: (.[0].project // "?"), value: length}) | from_entries)
        },
        daily: ($st | group_by(.ts[0:10])
                    | map({key: .[0].ts[0:10], value: length}) | from_entries)
      }
  ' "$WORK/sessions.raw" > "$WORK/sessions.json"

  jq -s --arg testre "$USAGE_TEST_RE" --arg runre "$USAGE_RUN_RE" '
    [.[] | select(.phase=="pre")] as $pre
    | [.[] | select(.phase=="fail")] as $fail
    | ($pre | map(select(.tool=="Edit" or .tool=="Write" or .tool=="MultiEdit")
                  | (.input.file_path // "")) | map(select(. != ""))) as $edits
    | {
        tools: {
          top: ($pre | group_by(.tool // "?")
                     | map({name: (.[0].tool // "?"), count: length})
                     | sort_by(-.count) | .[0:15]),
          failures_total: ($fail | length),
          failures_by_tool: ($fail | group_by(.tool // "?")
                                   | map({name: (.[0].tool // "?"), count: length})
                                   | sort_by(-.count))
        },
        skills_top: ($pre | map(select(.tool=="Skill") | (.input.skill // "(unknown)"))
                          | group_by(.) | map({name: .[0], count: length})
                          | sort_by(-.count) | .[0:15]),
        exit_plan_mode_count: ($pre | map(select(.tool=="ExitPlanMode")) | length),
        tdd: {
          test_edits: ($edits | map(select(test($testre))) | length),
          prod_edits: ($edits | map(select(test($testre) | not)) | length),
          test_runs: ($pre | map(select(.tool=="Bash") | (.input.command // ""))
                           | map(select(. != "" and test($runre))) | length)
        }
      }
  ' "$WORK/tools.raw" > "$WORK/tools.json"

  jq -s --arg slashre "$USAGE_SLASH_RE" '
    . as $all
    | ($all | length) as $n
    | [$all[] | select(.slash_command != null and .slash_command != "")
              | (.slash_command | split("\n")[0]) | select(test($slashre))] as $slash
    | ["не так", "не работает", "не то", "снова", "опять", "неправильно", "wrong", "still not"] as $kw
    | {
        prompts: {
          count: $n,
          mean_length: (if $n == 0 then 0 else ([$all[].length // 0] | add / $n | round) end),
          median_length: (if $n == 0 then 0 else ([$all[].length // 0] | sort | .[($n / 2 | floor)]) end),
          slash_pct: (if $n == 0 then 0 else ((10000 * ($slash | length) / $n | round) / 100) end),
          cyrillic_pct: (if $n == 0 then 0
                         else ((10000 * ([$all[] | select((.head // "") | test("[а-яА-ЯёЁ]"))] | length) / $n
                                | round) / 100) end)
        },
        slash_top: ($slash | group_by(.) | map({name: .[0], count: length})
                           | sort_by(-.count) | .[0:15]),
        friction: {
          total: ([$all[] | (.head // "") as $h
                          | select(any($kw[]; . as $k | ($h | test($k; "i"))))] | length),
          by_keyword: ([$kw[] as $k
                        | {key: $k, value: ([$all[] | select((.head // "") | test($k; "i"))] | length)}
                        | select(.value > 0)] | from_entries)
        }
      }
  ' "$WORK/prompts.raw" > "$WORK/prompts.json"

  # Стопы кумулятивны: токены сессии за окно = (последний стоп в окне) минус
  # (последний стоп до окна). Сессия учитывается, если её последний стоп в окне
  # действительно попадает в окно.
  jq -s --arg from "$from_iso" --arg to "$to_iso" '
    group_by(.session)
    | map(
        sort_by(.ts)
        | (map(select(.ts < $to)) | last) as $in_row
        | (map(select(.ts < $from)) | last) as $before
        | select($in_row != null and $in_row.ts >= $from)
        | {
            project: ($in_row.project // "?"),
            input:       (($in_row.input_tokens // 0) - ($before.input_tokens // 0)),
            output:      (($in_row.output_tokens // 0) - ($before.output_tokens // 0)),
            cache_read:  (($in_row.cache_read // 0)   - ($before.cache_read // 0)),
            cache_write: (($in_row.cache_write // 0)  - ($before.cache_write // 0)),
            turns:       (($in_row.turns // 0)        - ($before.turns // 0)),
            models: ([.[] | select(.ts >= $from and .ts < $to) | .models[]?
                          | select(. != "<synthetic>")] | unique)
          }
      ) as $sess
    | {
      tokens: {
        input: ($sess | map(.input) | add // 0),
        output: ($sess | map(.output) | add // 0),
        cache_read: ($sess | map(.cache_read) | add // 0),
        cache_write: ($sess | map(.cache_write) | add // 0),
        turns: ($sess | map(.turns) | add // 0),
        by_project_top: ($sess | group_by(.project)
                         | map({project: .[0].project,
                                input: (map(.input) | add),
                                output: (map(.output) | add)})
                         | sort_by(-(.input + .output)) | .[0:5])
      },
      models: ([$sess[].models[]]
               | group_by(.) | map({key: .[0], value: length}) | from_entries)
    }
  ' "$WORK/stops.raw" > "$WORK/stops.json"

  jq -s '
    {top: ([.[] | select(.event=="SubagentStart") | (.agent_type // "(unspecified)")]
           | group_by(.) | map({name: .[0], count: length})
           | sort_by(-.count) | .[0:15])}
  ' "$WORK/subagents.raw" > "$WORK/subagents.json"

  jq -s '
    {by_kind: (group_by(.kind // "?") | map({key: (.[0].kind // "?"), value: length}) | from_entries),
     total: length}
  ' "$WORK/blocks.raw" > "$WORK/blocks.json"

  local ccu_json
  ccu_json=$(ccusage_enrich "$start_epoch" $((start_epoch + WEEK_SECONDS)))

  mkdir -p "$OUT_DIR"
  tmp_file="$OUT_DIR/.$week_id.json.tmp"
  jq -n \
    --arg week "$week_id" --arg from "$from_iso" --arg to "$to_iso" --arg gen "$gen_ts" \
    --argjson sess "$(cat "$WORK/sessions.json")" \
    --argjson tools "$(cat "$WORK/tools.json")" \
    --argjson prompts "$(cat "$WORK/prompts.json")" \
    --argjson stops "$(cat "$WORK/stops.json")" \
    --argjson subs "$(cat "$WORK/subagents.json")" \
    --argjson blocks "$(cat "$WORK/blocks.json")" \
    --argjson ccu "$ccu_json" \
    '{
      schema_version: 1,
      week: $week,
      range: {from: $from, to: $to},
      generated_at: $gen,
      sessions: $sess.sessions,
      daily_sessions: $sess.daily,
      active_days: ($sess.daily | keys | length),
      peak: (if ($sess.daily | length) == 0 then {date: null, sessions: 0}
             else ($sess.daily | to_entries | max_by(.value) | {date: .key, sessions: .value}) end),
      tokens: $stops.tokens,
      models: $stops.models,
      tools: $tools.tools,
      skills: {top: $tools.skills_top},
      slash_commands: {top: $prompts.slash_top},
      subagents: {top: $subs.top},
      prompts: $prompts.prompts,
      plan_mode: {exit_plan_mode_count: $tools.exit_plan_mode_count},
      tdd: $tools.tdd,
      blocks: $blocks,
      friction: $prompts.friction,
      enrichment: {ccusage: $ccu}
    }' > "$tmp_file"
  mv "$tmp_file" "$out_file"
  echo "OK: $out_file"
}

# --- Main ---

# --print-window: печатает "<prev> <week> <next>" для целевого окна и выходит.
# Runner использует это вместо собственной date-арифметики.
if [ "$PRINT_WINDOW" -eq 1 ]; then
  if [ -n "$WEEK" ]; then
    start=$(resolve_week_start "$WEEK")
  else
    last=$(last_completed_index)
    [ "$last" -ge 0 ] || { echo "Нет завершённых окон" >&2; exit 1; }
    start=$((ANCHOR_EPOCH + last * WEEK_SECONDS))
  fi
  echo "$(week_id_of $((start - WEEK_SECONDS))) $(week_id_of "$start") $(week_id_of $((start + WEEK_SECONDS)))"
  exit 0
fi

if [ "$MODE" = "backfill" ]; then
  last=$(last_completed_index)
  [ "$last" -ge 0 ] || { echo "Нет завершённых окон (сейчас идёт первое)" >&2; exit 1; }
  for i in $(seq 0 "$last"); do
    start=$((ANCHOR_EPOCH + i * WEEK_SECONDS))
    wid=$(week_id_of "$start")
    if [ -f "$OUT_DIR/$wid.json" ] && [ "$FORCE" -ne 1 ]; then
      echo "skip: $wid (уже существует)"
      continue
    fi
    collect_window "$wid" "$start"
  done
elif [ -n "$WEEK" ]; then
  start=$(resolve_week_start "$WEEK")
  collect_window "$WEEK" "$start"
else
  last=$(last_completed_index)
  [ "$last" -ge 0 ] || { echo "Нет завершённых окон (сейчас идёт первое)" >&2; exit 1; }
  start=$((ANCHOR_EPOCH + last * WEEK_SECONDS))
  collect_window "$(week_id_of "$start")" "$start"
fi
