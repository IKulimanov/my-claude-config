#!/bin/bash

# ── Настройки ────────────────────────────────────────
SHOW_COST=false      # Показывать стоимость сессии ($)
SHOW_TOKENS=true     # Показывать токены в абсолютных числах (42k/200k)
# ─────────────────────────────────────────────────────

# Проверка зависимостей
command -v jq >/dev/null 2>&1 || { printf "statusline: jq not found"; exit 0; }

input=$(cat)

GREEN=$'\033[32m'
YELLOW=$'\033[33m'
RED=$'\033[91m'
DIM=$'\033[2m'
RESET=$'\033[0m'

# ── Парсинг JSON ──────────────────────────────────────
MODEL=$(echo "$input"     | jq -r '.model.display_name // "Claude"')
CTX=$(echo "$input"       | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
USED_TOK=$(echo "$input"  | jq -r '.context_window.used_tokens // 0')
TOTAL_TOK=$(echo "$input" | jq -r '.context_window.total_tokens // 0')
FIVE=$(echo "$input"      | jq -r '.rate_limits.five_hour.used_percentage // 0' | cut -d. -f1)
RESETS_AT=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // 0')
COST=$(echo "$input"      | jq -r '.cost.total_cost_usd // 0')

# ── Цвета по порогам ─────────────────────────────────
if   [ "$CTX" -ge 80 ]; then CTX_COLOR=$RED
elif [ "$CTX" -ge 50 ]; then CTX_COLOR=$YELLOW
else                         CTX_COLOR=$GREEN
fi

if   [ "$FIVE" -ge 80 ]; then FIVE_COLOR=$RED
elif [ "$FIVE" -ge 50 ]; then FIVE_COLOR=$YELLOW
else                          FIVE_COLOR=$GREEN
fi

# ── Форматирование токенов (например, 42k/200k) ──────
format_tokens() {
  local n=$1
  if   [ "$n" -ge 1000000 ]; then printf "%.1fM" "$(echo "scale=1; $n/1000000" | bc)"
  elif [ "$n" -ge 1000 ];    then printf "%dk" $(( n / 1000 ))
  else                            printf "%d" "$n"
  fi
}

TOKENS_STR=""
if [ "$SHOW_TOKENS" = true ] && [ "$USED_TOK" -gt 0 ]; then
  USED_FMT=$(format_tokens "$USED_TOK")
  if [ "$TOTAL_TOK" -gt 0 ]; then
    TOTAL_FMT=$(format_tokens "$TOTAL_TOK")
    TOKENS_STR=" ${DIM}(${USED_FMT}/${TOTAL_FMT})${RESET}"
  else
    TOKENS_STR=" ${DIM}(${USED_FMT})${RESET}"
  fi
fi

# ── Время до сброса 5h-лимита ────────────────────────
NOW=$(date +%s)
DIFF=$(( RESETS_AT - NOW ))
if [ "$RESETS_AT" -eq 0 ] || [ "$DIFF" -le 0 ]; then
  TIME_LEFT="сброс"
else
  HOURS=$(( DIFF / 3600 ))
  MINS=$(( (DIFF % 3600) / 60 ))
  TIME_LEFT=$(printf "%dh%02dm" $HOURS $MINS)
fi

# ── Сборка строки ────────────────────────────────────
LINE=" $MODEL │ ctx: ${CTX_COLOR}${CTX}%${RESET}${TOKENS_STR} │ 5h: ${FIVE_COLOR}${FIVE}%${RESET} (↺${TIME_LEFT})"

if [ "$SHOW_COST" = true ]; then
  LINE="$LINE │ \$$(printf '%.4f' "$COST")"
fi

printf "%s" "$LINE"
