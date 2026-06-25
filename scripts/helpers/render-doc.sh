#!/usr/bin/env bash
# Рендерит markdown-артефакт (план, ревью, дайджест) в HTML или PDF.
# Детерминированная механика — поэтому скрипт, а не prompt каждый запуск.
# Используется командами, которым нужен экспортируемый документ (/review-mr, /reflect, дайджест).
#
# Использование:
#   render-doc.sh <input.md> [html|pdf] [output]
#
# format — html (default) или pdf.
# output — путь результата (default: рядом с входом, со сменой расширения).
#
# Требует pandoc. Для pdf нужен также движок (wkhtmltopdf или TeX). Если инструмента
# нет — скрипт завершается с понятной ошибкой и ненулевым кодом (не делает вид, что отрендерил).

set -euo pipefail

INPUT="${1:-}"
FORMAT="${2:-html}"
OUTPUT="${3:-}"

if [ -z "$INPUT" ]; then
  echo "Usage: render-doc.sh <input.md> [html|pdf] [output]" >&2
  exit 1
fi

if [ ! -f "$INPUT" ]; then
  echo "Входной файл не найден: $INPUT" >&2
  exit 1
fi

case "$FORMAT" in
  html|pdf) ;;
  *) echo "Неизвестный формат: $FORMAT (ожидается html|pdf)" >&2; exit 1 ;;
esac

if [ -z "$OUTPUT" ]; then
  OUTPUT="${INPUT%.*}.$FORMAT"
fi

if ! command -v pandoc >/dev/null 2>&1; then
  echo "pandoc не установлен. Установи: brew install pandoc (для pdf также wkhtmltopdf или TeX)." >&2
  exit 1
fi

if [ "$FORMAT" = "pdf" ]; then
  ENGINE=""
  if command -v wkhtmltopdf >/dev/null 2>&1; then
    ENGINE="--pdf-engine=wkhtmltopdf"
  elif command -v pdflatex >/dev/null 2>&1 || command -v tectonic >/dev/null 2>&1; then
    ENGINE=""   # pandoc сам выберет TeX-движок
  else
    echo "Для pdf нужен движок: wkhtmltopdf или TeX (pdflatex/tectonic). Установи один из них." >&2
    exit 1
  fi
  # shellcheck disable=SC2086
  pandoc "$INPUT" -o "$OUTPUT" $ENGINE
else
  pandoc "$INPUT" -s -o "$OUTPUT"
fi

echo "$OUTPUT"
