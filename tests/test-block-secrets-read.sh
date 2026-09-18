#!/usr/bin/env bash
# Тест: block-secrets.sh — для Bash блокируется чтение секретных файлов, а не упоминание их имени;
# для Read/Edit/Write — путь как раньше.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/hooktest.sh"
hooktest_init
HOOK="$SCRIPT_DIR/../hooks/scripts/block-secrets.sh"

e() { expect_decision "$HOOK" "$1" "$2" "$TMP" "$3"; }

# Bash: чтение — deny
e deny  Bash 'cat .env'
e deny  Bash 'source .env && ./run.sh'
e deny  Bash 'grep -n TOKEN .env'
e deny  Bash 'cat ~/.ssh/id_rsa'
e deny  Bash 'head -c 100 config/.env.production'
e deny  Bash 'cp .env /tmp/x'

# Bash: имя без чтения — allow
e allow Bash "find . -maxdepth 2 -name '*.env*'"
e allow Bash 'ls -la .env'
e allow Bash 'echo "=== .env ==="'
e allow Bash 'test -f .env && echo yes'
e allow Bash 'git check-ignore .env'
e allow Bash "rsync -a --exclude 'tools/.env' src/ dst/"
e allow Bash "find . -not -path '*/.ssh/*' -type f"
e deny  Bash "rsync -a --exclude 'x' .env dst/"
e allow Bash 'git status --short'
e allow Bash 'mvn -q test'

# Ложные срабатывания из практики (2026-09-04): .envrc — не секрет, поиск по слову .env — не чтение файла.
e allow Bash 'cat .envrc'
e allow Bash 'grep -rn ".env" docs/'
e allow Bash 'rg -n "\.env" src/'
e allow Bash 'cat > notes.md <<EOF
переменные лежат в .envrc
EOF'
e deny  Bash 'grep -r password .env'
e deny  Bash 'cat prod.env'
# Ключи и хранилища
e deny  Bash 'base64 server.pem'
e deny  Bash 'cat ~/.kube/kubeconfig'
e deny  Bash 'cat ~/.kube/config'
e deny  Bash 'cat key.p12'
e deny  Bash 'cat keystore.jks'
e deny  Bash 'cat ~/.gnupg/secring.gpg'

# Инструменты файлов
e deny  Read  "/x/.env"
e deny  Edit  "/x/.env.local"
e allow Read  "/x/.env.example"
e allow Read  "/x/src/Main.java"
e deny  Read  "/x/certs/key.p12"
e allow Read  "/x/.envrc"
e allow Read  "/x/node_modules/pkg/.env"

echo "OK: test-block-secrets-read (чтение — deny, упоминание — allow)"
