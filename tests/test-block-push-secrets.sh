#!/usr/bin/env bash
# Регрессия block-push-secrets.sh.
# Хук должен: ловить секрет в НЕотправленных коммитах, пропускать то, что уже на сервере
# (полный скан этого репозитория ложно находил примеры строк подключения из документации),
# уважать .trufflehogignore и честно сообщать о пропуске скана, если trufflehog не установлен.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$ROOT/hooks/scripts/block-push-secrets.sh"
CLAUDE_LOG_DIR="$(mktemp -d)"
export CLAUDE_LOG_DIR
W="$(mktemp -d)"
trap 'rm -rf "$CLAUDE_LOG_DIR" "$W"' EXIT

pass=0; fail=0
t() { if [ "$2" = "$3" ]; then printf '  OK     %s\n' "$1"; pass=$((pass+1));
      else printf '  ПРОВАЛ %s: ждали "%s", получили "%s"\n' "$1" "$3" "$2"; fail=$((fail+1)); fi; }

run() { # <cwd> -> печатает deny|allow
  local out
  out=$(printf '{"tool_name":"Bash","tool_input":{"command":"git push origin main"},"cwd":"%s","session_id":"t"}' "$1" \
        | "$H" 2>/dev/null || true)
  if echo "$out" | grep -q '"permissionDecision": *"deny"'; then echo deny; else echo allow; fi
}

if ! command -v trufflehog >/dev/null 2>&1; then
  echo "trufflehog не установлен — проверяем только режим честного пропуска"
  t "не-push команда пропускается" \
    "$(printf '{"tool_name":"Bash","tool_input":{"command":"git status"},"cwd":"/tmp","session_id":"t"}' | "$H" >/dev/null 2>&1 && echo allow)" \
    "allow"
  t "пропуск скана записан в журнал" \
    "$(run /tmp >/dev/null; jq -r 'select(.kind=="scan-skipped") | .kind' "$CLAUDE_LOG_DIR/blocks.jsonl" 2>/dev/null | head -1)" \
    "scan-skipped"
  echo; echo "Итого: $pass пройдено, $fail провалено"; [ "$fail" -eq 0 ]; exit
fi

# Готовим репозиторий: "серверная" ветка с примером из документации + новый локальный коммит.
git init -q "$W/repo"
cd "$W/repo"
git config user.email t@t; git config user.name t; git config commit.gpgsign false
mkdir -p docs
echo 'Пример строки подключения: jdbc:postgresql://localhost:5432/mydb?user=app&password=app' > docs/example.md
git add -A && git commit -qm "документация с примером"
git clone -q --bare . "$W/origin.git"
git remote add origin "$W/origin.git"
git fetch -q origin
git branch -q --set-upstream-to=origin/"$(git rev-parse --abbrev-ref HEAD)" 2>/dev/null || true

t "уже отправленное не блокирует push" "$(run "$W/repo")" "allow"

# Новый, ещё не отправленный коммит с настоящим на вид ключом.
printf 'db.url=jdbc:mysql://db.internal:3306/prod?user=root&password=Zx9qLmTrv2Wk\n' > creds.ini
git add -A && git commit -qm "добавил ключ по ошибке"

t "секрет в новом коммите блокирует push" "$(run "$W/repo")" "deny"
t "в журнале указано место находки" \
  "$(jq -r 'select(.kind=="push-secrets") | (.where | length > 0)' "$CLAUDE_LOG_DIR/blocks.jsonl" 2>/dev/null | head -1)" \
  "true"

# .trufflehogignore должен снимать находку.
echo 'creds.ini' > .trufflehogignore
git add -A && git commit -qm "исключение для сканера"
t ".trufflehogignore исключает путь" "$(run "$W/repo")" "allow"

cd "$ROOT"
echo
echo "Итого: $pass пройдено, $fail провалено"
[ "$fail" -eq 0 ]
