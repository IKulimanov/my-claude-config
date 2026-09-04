#!/usr/bin/env bash
# Регрессия block-secrets.sh: блокировать реальные обращения к секретам и НЕ блокировать
# обычную работу. Случаи «должны пропускаться» — это реальные ложные срабатывания,
# пойманные после установки конфига 2026-09-04.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
H="$ROOT/hooks/scripts/block-secrets.sh"
CLAUDE_LOG_DIR="$(mktemp -d)"
export CLAUDE_LOG_DIR
trap 'rm -rf "$CLAUDE_LOG_DIR"' EXIT

pass=0; fail=0

check() { # <ожидание deny|allow> <описание> <json>
  local want="$1" desc="$2" json="$3" out got
  out=$(printf '%s' "$json" | "$H" 2>/dev/null || true)
  if echo "$out" | grep -q '"permissionDecision": *"deny"'; then got=deny; else got=allow; fi
  if [ "$got" = "$want" ]; then
    printf '  OK    %-6s %s\n' "$got" "$desc"; pass=$((pass+1))
  else
    printf '  ПРОВАЛ ждали %s, получили %s — %s\n' "$want" "$got" "$desc"; fail=$((fail+1))
  fi
}

b() { printf '{"tool_name":"Bash","tool_input":{"command":%s},"cwd":"/tmp","session_id":"t"}' "$1"; }
r() { printf '{"tool_name":"Read","tool_input":{"file_path":%s},"cwd":"/tmp","session_id":"t"}' "$1"; }

echo "Должны БЛОКИРОВАТЬСЯ:"
check deny  "чтение приватного ключа через Read"      "$(r '"/Users/ivan/.ssh/id_rsa"')"
check deny  "чтение .env через Read"                  "$(r '"/proj/.env"')"
check deny  "cat приватного ключа"                    "$(b '"cat ~/.ssh/id_rsa"')"
check deny  "копирование ключа наружу"                "$(b '"cp /home/u/.ssh/id_ed25519 /tmp/x"')"
check deny  "чтение kubeconfig"                       "$(b '"cat ~/.kube/kubeconfig"')"
check deny  "base64 сертификата"                      "$(b '"base64 server.pem"')"

echo
echo "Должны ПРОПУСКАТЬСЯ (раньше ложно блокировались):"
check allow "комментарий со словом .envrc в heredoc"  "$(b '"python3 - <<PY\ns=s.replace(\"brew direnv # авто-загрузка .envrc\")\nPY"')"
check allow "поиск по слову .env в документации"      "$(b '"grep -rn \".env\" docs/"')"
check allow "чтение .env.example"                     "$(r '"/proj/.env.example"')"
check allow "упоминание пути в echo"                  "$(b '"echo \"положи ключ в ~/.ssh/id_rsa\""')"
check allow "обычная сборка"                          "$(b '"mvn -q test"')"
check allow "git diff"                                "$(b '"git diff --stat"')"
check allow "cat обычного файла"                      "$(b '"cat README.md"')"
check allow "правка Makefile"                         "$(r '"/Users/ivan/dotfiles/Makefile"')"

echo
echo "Итого: $pass пройдено, $fail провалено"
[ "$fail" -eq 0 ]
