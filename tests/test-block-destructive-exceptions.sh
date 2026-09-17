#!/usr/bin/env bash
# Тест: block-destructive.sh — rm -rf сборочных и scratch-каталогов разрешён, остальное блокируется;
# git push больше не дело этого хука (им занимается guard-git.sh).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/block-destructive.sh"

e() { expect_decision "$HOOK" "$1" Bash "$TMP" "$2"; }

e allow 'rm -rf target/surefire-reports && mvn -q test'
e allow 'rm -rf build dist node_modules'
e allow 'rm -rf /Users/x/dev/demo/config-manager/target'
e allow 'rm -rf /private/tmp/claude-501/x/scratchpad/tmp1'
e allow 'rm -rf ./target/'
e deny  'rm -rf src'
e deny  'rm -rf /'
e deny  'rm -rf target ../other'
e deny  'rm -rf /tmp/vaultjar'
e deny  'DROP TABLE users'
e deny  'chmod 777 /etc'
e allow 'git push --force origin master'
e allow 'mvn -q test'

echo "OK: test-block-destructive-exceptions (сборочные и scratch — allow, остальное — deny)"
