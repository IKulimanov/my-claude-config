#!/usr/bin/env bash
# Чинит и нормализует ~/.claude/logs/*.jsonl.
#
# Зачем: раньше хуки писали pretty-printed (многострочный) JSON. При гонке или
# частичной записи это ломало jq-стрим (например, у записи терялась открывающая
# скобка), и analyze-usage.sh падал. Корневая причина устранена в hook_log
# (теперь строго одна строка на запись), но накопленные логи нужно почистить.
#
# Скрипт извлекает все валидные JSON-объекты (толерантный парсер пропускает
# повреждённые фрагменты) и перезаписывает файл строгим JSONL: один компактный
# объект на строку. Повреждённые записи отбрасываются с отчётом.
#
# Использование:
#   ./scripts/repair-logs.sh           # dry-run: только показать, что изменится
#   ./scripts/repair-logs.sh --apply   # реально починить (с бэкапом *.bak)

set -euo pipefail

LOG_DIR="${CLAUDE_LOG_DIR:-$HOME/.claude/logs}"
APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

if [ ! -d "$LOG_DIR" ]; then
  echo "No logs found at $LOG_DIR" >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "python3 required" >&2; exit 1; }

# Толерантный нормализатор: stdin -> stdout (строгий JSONL).
# На stderr печатает: <recovered> <dropped_chars>
# Программа передаётся через -c, чтобы stdin оставался лог-файлом.
NORMALIZE_PY='
import json, sys
text = sys.stdin.read()
dec = json.JSONDecoder()
i, n = 0, len(text)
recovered, dropped = 0, 0
out = []
while i < n:
    while i < n and text[i] in " \t\r\n":
        i += 1
    if i >= n:
        break
    try:
        obj, end = dec.raw_decode(text, i)
    except json.JSONDecodeError:
        j = text.find("{", i + 1)
        dropped += (j if j != -1 else n) - i
        if j == -1:
            break
        i = j
        continue
    if isinstance(obj, dict):
        out.append(json.dumps(obj, ensure_ascii=False, separators=(",", ":")))
        recovered += 1
    else:
        dropped += end - i
    i = end
sys.stdout.write("\n".join(out))
if out:
    sys.stdout.write("\n")
sys.stderr.write("{} {}".format(recovered, dropped))
'
normalize() {
  python3 -c "$NORMALIZE_PY"
}

echo "Repair logs in: $LOG_DIR"
[ "$APPLY" -eq 1 ] && echo "(apply mode — файлы будут перезаписаны, бэкап в *.bak)" || echo "(dry-run — изменения не записываются; запусти с --apply)"
echo

shopt -s nullglob
for f in "$LOG_DIR"/*.jsonl; do
  [ -f "$f" ] || continue
  before_lines=$(wc -l < "$f" | tr -d ' ')
  tmp=$(mktemp)
  stats=$(normalize < "$f" 2>&1 >"$tmp" ) || true
  # normalize пишет stats в stderr; перехватим отдельно
  recovered=${stats%% *}
  dropped=${stats##* }
  after_lines=$(wc -l < "$tmp" | tr -d ' ')
  status="ok"
  [ "${dropped:-0}" -gt 0 ] && status="recovered, dropped ${dropped}b"
  printf "  %-22s %5s rec, %4s->%-4s lines  [%s]\n" "$(basename "$f")" "$recovered" "$before_lines" "$after_lines" "$status"
  if [ "$APPLY" -eq 1 ]; then
    cp "$f" "$f.bak"
    mv "$tmp" "$f"
  else
    rm -f "$tmp"
  fi
done

echo
if [ "$APPLY" -eq 1 ]; then
  echo "Готово. Оригиналы сохранены как *.bak"
else
  echo "Это был dry-run. Для применения: ./scripts/repair-logs.sh --apply"
fi
