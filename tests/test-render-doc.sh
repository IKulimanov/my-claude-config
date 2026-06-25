#!/usr/bin/env bash
# Тест render-doc.sh: валидирует аргументы и рендерит markdown в html.
# Если pandoc недоступен — путь рендера пропускается (помечается SKIP), но
# проверка аргументов и понятная ошибка про отсутствие инструмента проверяются всегда.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER="$SCRIPT_DIR/../scripts/helpers/render-doc.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $1" >&2; exit 1; }

# 1) Без аргументов — ошибка и usage, ненулевой код.
if "$RENDER" >/dev/null 2>&1; then
  fail "render-doc без аргументов должен падать"
fi

# 2) Несуществующий входной файл — понятная ошибка, ненулевой код.
if "$RENDER" "$TMP/nope.md" html >/dev/null 2>&1; then
  fail "render-doc на несуществующем файле должен падать"
fi

printf '# Title\n\nHello.\n' > "$TMP/doc.md"

if command -v pandoc >/dev/null 2>&1; then
  # 3a) pandoc есть: html создаётся и содержит контент.
  out="$TMP/doc.html"
  "$RENDER" "$TMP/doc.md" html "$out" >/dev/null 2>&1 || fail "рендер html упал при наличии pandoc"
  [ -s "$out" ] || fail "html-файл не создан или пуст"
  grep -qi "Hello" "$out" || fail "html не содержит контент"
  echo "OK: test-render-doc (валидация + html рендер через pandoc)"
else
  # 3b) pandoc нет: рендер должен завершиться понятной ошибкой о недостающем инструменте.
  if "$RENDER" "$TMP/doc.md" html "$TMP/doc.html" >/dev/null 2>&1; then
    fail "без pandoc рендер не должен молча 'успевать'"
  fi
  echo "OK: test-render-doc (валидация; рендер SKIP — pandoc не установлен)"
fi
