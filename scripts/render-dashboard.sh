#!/usr/bin/env bash
# Рендерит автономный дашборд analytics/dashboard.html из недельных снапшотов
# analytics/history/*.json и выдержек последнего отчёта analytics/reports/*.md.
# Шаблон: templates/dashboard.html.template (маркер __ANALYTICS_DATA__ внутри
# <script type="application/json">). Файл самодостаточен: без CDN, офлайн.
#
# Использование:
#   render-dashboard.sh [--history DIR] [--reports DIR] [--template FILE] [--out FILE]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HISTORY_DIR="$REPO_ROOT/analytics/history"
REPORTS_DIR="$REPO_ROOT/analytics/reports"
TEMPLATE="$REPO_ROOT/templates/dashboard.html.template"
OUT="$REPO_ROOT/analytics/dashboard.html"

command -v jq >/dev/null 2>&1 || { echo "jq не найден" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --history)  HISTORY_DIR="$2"; shift 2 ;;
    --reports)  REPORTS_DIR="$2"; shift 2 ;;
    --template) TEMPLATE="$2"; shift 2 ;;
    --out)      OUT="$2"; shift 2 ;;
    *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
  esac
done

[ -d "$HISTORY_DIR" ] || { echo "Нет каталога истории: $HISTORY_DIR" >&2; exit 1; }
[ -f "$TEMPLATE" ] || { echo "Нет шаблона: $TEMPLATE" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Выдержка секции markdown-отчёта: строки между "## <заголовок>" и следующим "## ".
extract_section() {
  awk -v h="## $2" '
    $0 == h { grab = 1; next }
    grab && /^## / { exit }
    grab { print }
  ' "$1"
}

# --- Последний отчёт (по имени недели; имена сортируются лексикографически) ---
report_json='{"week": null, "red_flags": "", "experiment": ""}'
if [ -d "$REPORTS_DIR" ]; then
  latest_report=$(ls "$REPORTS_DIR"/*.md 2>/dev/null | sort | tail -1 || true)
  if [ -n "${latest_report:-}" ]; then
    report_week=$(basename "$latest_report" .md)
    report_json=$(jq -n \
      --arg week "$report_week" \
      --rawfile red <(extract_section "$latest_report" "Красные флаги") \
      --rawfile exp <(extract_section "$latest_report" "Эксперимент недели") \
      '{week: $week, red_flags: ($red | gsub("^\\s+|\\s+$"; "")), experiment: ($exp | gsub("^\\s+|\\s+$"; ""))}')
  fi
fi

# --- Payload: все снапшоты, отсортированные по неделе, + выдержки отчёта ---
ls "$HISTORY_DIR"/*.json >/dev/null 2>&1 || { echo "В $HISTORY_DIR нет снапшотов" >&2; exit 1; }
jq -s --argjson report "$report_json" \
  '{weeks: (sort_by(.week)), latest_report: $report}' \
  "$HISTORY_DIR"/*.json > "$WORK/payload.json"

# Экранируем </ внутри JSON (валидный JSON-эскейп), чтобы содержимое отчёта
# не могло закрыть <script>-блок.
sed 's;</;<\\/;g' "$WORK/payload.json" > "$WORK/payload.escaped.json"

# --- Вставка в шаблон по строке-маркеру (awk: payload большой, sed опасен) ---
awk -v datafile="$WORK/payload.escaped.json" '
  $0 ~ /^__ANALYTICS_DATA__$/ {
    while ((getline line < datafile) > 0) print line
    close(datafile)
    next
  }
  { print }
' "$TEMPLATE" > "$WORK/dashboard.html"

mkdir -p "$(dirname "$OUT")"
mv "$WORK/dashboard.html" "$OUT"
echo "OK: $OUT"
