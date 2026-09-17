#!/usr/bin/env bash
# Тест: guard-paths.sh — ask на запись в .gitlab-ci.yml, .gitlab/ и helm/ через Edit/Write/MultiEdit
# и через Bash; чтение и остальные пути — allow.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/guard-paths.sh"
REPO="/Users/x/dev/work/java/demo"

e() { expect_decision "$HOOK" "$1" "$2" "$REPO" "$3"; }

# Инструменты редактирования
e ask   Edit      "$REPO/helm/staging/demo-values.yml"
e ask   Write     "$REPO/.gitlab-ci.yml"
e ask   Edit      "$REPO/.gitlab/merge_request_templates/default.md"
e ask   MultiEdit "$REPO/helm/Chart.yaml"
e ask   Write     "$REPO/.gitlab-ci.yaml"
e allow Edit      "$REPO/src/main/java/Foo.java"
e allow Edit      "$REPO/docs/helm-notes.md"
e allow Edit      "$REPO/src/main/resources/application.yml"

# Bash: запись — ask, чтение — allow
e allow Bash 'cat helm/values.yaml'
e allow Bash 'git diff helm/'
e allow Bash 'grep -n image .gitlab-ci.yml'
e allow Bash 'ls helm'
e ask   Bash "sed -i '' 's/a/b/' helm/staging/demo-values.yml"
e ask   Bash $'cat > .gitlab-ci.yml <<\'EOF\'\nstages: []\nEOF'
e ask   Bash 'echo x >> helm/values.yaml'
e ask   Bash 'cp values.yaml helm/values.yaml'
e ask   Bash 'rm helm/old.yaml'
e ask   Bash 'tee .gitlab/ci/build.yml < in.yml'
e ask   Bash 'mv helm/a.yaml helm/b.yaml'
e allow Bash 'mvn -q test'

grep -q '"kind":"protected-path"' "$CLAUDE_LOG_DIR/blocks.jsonl" || fail "нет записи kind=protected-path"

echo "OK: test-guard-paths (Edit/Write/MultiEdit и Bash-запись — ask, чтение — allow)"
