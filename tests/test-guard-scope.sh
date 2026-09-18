#!/usr/bin/env bash
# Тест guard-scope.sh: пока agent/scope.txt задачи активен, запись файла вне списка через Edit/Write/MultiEdit
# требует подтверждения (ask). Файлы из списка, артефакты .claude/tasks/, файлы вне репозитория, завершённый
# scope и ветка без задачи — allow. Bash хук не смотрит (это guard-paths и guard-tests).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/guard-scope.sh"
SCOPE="$SCRIPT_DIR/../scripts/helpers/scope.sh"

mkdir -p "$TMP/repo"
REPO=$(cd "$TMP/repo" && pwd -P)   # git печатает физический путь, cwd хука должен совпадать
git init -q -b feature/ORSP-7-export "$REPO"
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
mkdir -p "$REPO/src/main/java/kg" "$REPO/src/test/java/kg"
TASK="$REPO/.claude/tasks/ORSP-7"; mkdir -p "$TASK"
"$SCOPE" "$TASK" add src/main/java/kg/Foo.java 'src/test/java/kg/*' src/main/resources/db/ >/dev/null

e() { expect_decision "$HOOK" "$1" "$2" "$REPO" "$3"; }

# В scope: точное имя, маска, каталог (которого ещё нет).
e allow Edit      "$REPO/src/main/java/kg/Foo.java"
e allow Write     "$REPO/src/test/java/kg/sub/FooTest.java"
e allow Write     "$REPO/src/main/resources/db/V2__x.sql"
# Вне scope — ask, включая относительный путь и новый каталог.
e ask   Edit      "$REPO/src/main/java/kg/Bar.java"
e ask   Write     "$REPO/src/main/java/kg/new/Baz.java"
e ask   MultiEdit "$REPO/pom.xml"
e ask   Edit      "src/main/java/kg/Bar.java"
# Артефакты, чужой каталог, Bash и чтение — allow.
e allow Edit      "$REPO/.claude/tasks/ORSP-7/plan.md"
e allow Write     "$REPO/.claude/tasks/about.md"
e allow Edit      "$TMP/outside/Other.java"
e allow Bash      "sed -i '' 's/a/b/' src/main/java/kg/Bar.java"
e allow Read      "$REPO/src/main/java/kg/Bar.java"

grep -q '"kind":"scope"' "$CLAUDE_LOG_DIR/blocks.jsonl" || fail "нет записи kind=scope"

# Доработка: действует scope последнего каталога (ORSP-7-2).
TASK2="$REPO/.claude/tasks/ORSP-7-2"; mkdir -p "$TASK2"
"$SCOPE" "$TASK2" add src/main/java/kg/Bar.java >/dev/null
e allow Edit "$REPO/src/main/java/kg/Bar.java"
e ask   Edit "$REPO/src/main/java/kg/Foo.java"

# Завершённый scope — allow.
"$SCOPE" "$TASK2" done >/dev/null
e allow Edit "$REPO/src/main/java/kg/Foo.java"

# Ветка без задачи — allow.
git -C "$REPO" checkout -q -b feature/other
e allow Edit "$REPO/src/main/java/kg/Foo.java"

echo "OK: test-guard-scope (вне scope — ask; список, артефакты, чужой каталог, done, чужая ветка — allow)"
