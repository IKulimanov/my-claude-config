#!/usr/bin/env bash
# Тест: guard-tests.sh — правка закоммиченного и не изменённого тест-файла требует подтверждения (ask);
# новые и уже изменённые тест-файлы, прод-код и чтение — allow. Вариант 1 из плана (В5).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/guard-tests.sh"

REPO="$TMP/repo"
git init -q -b feature/x "$REPO"
mkdir -p "$REPO/src/test/java" "$REPO/src/main/java" "$REPO/pkg" "$REPO/src/components"
echo "class FooTest {}" > "$REPO/src/test/java/FooTest.java"
echo "class BazTest {}" > "$REPO/src/test/java/BazTest.java"
echo "class Foo {}" > "$REPO/src/main/java/Foo.java"
echo "package pkg" > "$REPO/pkg/foo_test.go"
echo "it('x')" > "$REPO/src/components/Foo.spec.ts"
git -C "$REPO" add -A
git -C "$REPO" -c user.name=t -c user.email=t@t commit -q -m init
echo "// изменён после коммита" >> "$REPO/src/test/java/BazTest.java"
echo "class BarTest {}" > "$REPO/src/test/java/BarTest.java"   # новый, не в git

e() { expect_decision "$HOOK" "$1" "$2" "$REPO" "$3"; }

# Инструменты редактирования
e ask   Edit      "$REPO/src/test/java/FooTest.java"
e ask   Write     "$REPO/src/test/java/FooTest.java"
e ask   MultiEdit "$REPO/src/test/java/FooTest.java"
e ask   Edit      "$REPO/pkg/foo_test.go"
e ask   Edit      "$REPO/src/components/Foo.spec.ts"
e allow Edit      "$REPO/src/test/java/BazTest.java"     # уже изменён относительно HEAD
e allow Edit      "$REPO/src/test/java/BarTest.java"     # не в git
e allow Write     "$REPO/src/test/java/NewTest.java"     # новый файл
e allow Edit      "$REPO/src/main/java/Foo.java"         # прод-код
e allow Edit      "$TMP/outside/SomeTest.java"           # вне git-репозитория

# Bash: запись — ask, чтение — allow
e ask   Bash "sed -i '' 's/a/b/' src/test/java/FooTest.java"
e ask   Bash 'rm src/test/java/FooTest.java'
e ask   Bash 'echo x >> src/test/java/FooTest.java'
e allow Bash 'cat src/test/java/FooTest.java'
e allow Bash 'mvn -Dtest=FooTest test'
e allow Bash 'git diff -- src/test/java/FooTest.java'

grep -q '"kind":"test-freeze"' "$CLAUDE_LOG_DIR/blocks.jsonl" || fail "нет записи kind=test-freeze"

echo "OK: test-guard-tests (закоммиченный тест — ask; новый, изменённый, прод-код, чтение — allow)"
