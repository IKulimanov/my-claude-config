#!/usr/bin/env bash
# Тест scope.sh: список файлов задачи в agent/scope.txt — add с заголовком и без дублей, done/active,
# check по точному имени, маске (`*` захватывает и `/`) и каталогу (строка с `/` на конце);
# завершённый или отсутствующий scope пропускает всё.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCOPE="$SCRIPT_DIR/../scripts/helpers/scope.sh"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

DIR="$TMP/task"; mkdir -p "$DIR"
F="$DIR/agent/scope.txt"

# 1) add создаёт файл с заголовком и строками; повтор не дублирует.
"$SCOPE" "$DIR" add src/main/java/kg/Foo.java 'src/test/java/kg/*' src/main/resources/db/ >/dev/null || fail "add упал"
[ "$(sed -n 1p "$F")" = "# scope: active" ] || fail "нет заголовка active: '$(sed -n 1p "$F")'"
"$SCOPE" "$DIR" add src/main/java/kg/Foo.java >/dev/null || fail "повторный add упал"
[ "$(grep -c 'kg/Foo.java' "$F")" = 1 ] || fail "дубль строки"
[ "$(grep -vc '^#' "$F")" = 3 ] || fail "ожидалось 3 строки scope, есть $(grep -vc '^#' "$F")"

# 2) check: точное имя, маска через подкаталоги, каталог; вне списка — код 1.
"$SCOPE" "$DIR" check src/main/java/kg/Foo.java || fail "точное имя не прошло"
"$SCOPE" "$DIR" check src/test/java/kg/a/b/FooTest.java || fail "маска * не захватила подкаталог"
"$SCOPE" "$DIR" check src/main/resources/db/V2__x.sql || fail "каталог с / на конце не прошёл"
"$SCOPE" "$DIR" check src/main/java/kg/Bar.java && fail "файл вне scope прошёл"
"$SCOPE" "$DIR" check src/main/resources/dbx/V1.sql && fail "похожий каталог прошёл"
"$SCOPE" "$DIR" check src/main/java/kg/Foo.java.bak && fail "имя с хвостом прошло"

# 3) done — всё проходит; active — снова проверяет; список цел.
"$SCOPE" "$DIR" done >/dev/null || fail "done упал"
[ "$(sed -n 1p "$F")" = "# scope: done" ] || fail "заголовок done"
"$SCOPE" "$DIR" check src/main/java/kg/Bar.java || fail "после done проверка не выключилась"
"$SCOPE" "$DIR" active >/dev/null || fail "active упал"
"$SCOPE" "$DIR" check src/main/java/kg/Bar.java && fail "после active проверка не включилась"
[ "$(grep -vc '^#' "$F")" = 3 ] || fail "смена статуса испортила список"

# 4) Нет scope.txt — check проходит; done без файла не падает.
mkdir -p "$TMP/empty"
"$SCOPE" "$TMP/empty" check anything.java || fail "без scope.txt должно проходить"
"$SCOPE" "$TMP/empty" done >/dev/null || fail "done без файла упал"

echo "OK: test-scope (add без дублей, check по имени, маске и каталогу, done/active)"
