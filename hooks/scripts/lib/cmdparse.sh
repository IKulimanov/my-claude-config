#!/usr/bin/env bash
# Разбор Bash-команд для хуков: сегменты, git-подкоманда, учёт `cd` и `git -C`.
# Source после lib/common.sh.

# Разбить команду на сегменты по && || ; | и переводам строк. Тела heredoc (от `<<MARK` до
# строки `MARK`) выбрасываются — это данные, а не команды. Каждый сегмент — одна строка.
cmd_segments() {
  local cmd="$1"
  awk '
    BEGIN { inhd = 0; mark = "" }
    {
      if (inhd) { if ($0 == mark) { inhd = 0 }; next }
      line = $0
      if (match(line, /<<-?[ \t]*['"'"'"]?[A-Za-z_][A-Za-z0-9_]*['"'"'"]?/)) {
        s = substr(line, RSTART, RLENGTH)
        sub(/^<<-?[ \t]*['"'"'"]?/, "", s)
        sub(/['"'"'"]$/, "", s)
        mark = s
        inhd = 1
      }
      gsub(/\|\||&&|;|\|/, "\n", line)
      print line
    }' <<<"$cmd" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | grep -v '^$' || true
}

# Если сегмент — вызов git, печатает "<подкоманда> <аргументы>" без глобальных опций git
# (-C <dir>, -c k=v, --git-dir=, --work-tree=, --no-pager). Иначе печатает пусто.
git_strip() {
  local seg="$1" rest
  [[ "$seg" =~ ^git([[:space:]]|$) ]] || { printf ''; return 0; }
  rest="${seg#git}"
  while :; do
    rest=$(printf '%s' "$rest" | sed -E 's/^[[:space:]]+//')
    case "$rest" in
      -C\ *)  rest=$(printf '%s' "$rest" | sed -E 's/^-C[[:space:]]+[^[:space:]]+//') ;;
      -c\ *)  rest=$(printf '%s' "$rest" | sed -E 's/^-c[[:space:]]+[^[:space:]]+//') ;;
      --git-dir=*|--work-tree=*|--no-pager*) rest=$(printf '%s' "$rest" | sed -E 's/^[^[:space:]]+//') ;;
      *) break ;;
    esac
  done
  printf '%s' "$rest"
}

# Значение `git -C <dir>` в сегменте или пусто.
git_c_dir() {
  local seg="$1"
  if [[ "$seg" =~ ^git[[:space:]]+(-c[[:space:]]+[^[:space:]]+[[:space:]]+)*-C[[:space:]]+([^[:space:]]+) ]]; then
    printf '%s' "${BASH_REMATCH[2]}"
  fi
}

# Каталог после `cd <dir>` относительно текущего: печатает новый каталог или прежний.
# Args: <segment> <current-dir>
cmd_apply_cd() {
  local seg="$1" cur="$2" target
  if [[ "$seg" =~ ^cd([[:space:]]+([^[:space:]]+))?$ ]]; then
    target="${BASH_REMATCH[2]:-}"
    target="${target%\"}"; target="${target#\"}"; target="${target%\'}"; target="${target#\'}"
    case "$target" in
      "") printf '%s' "$HOME" ;;
      -)  printf '%s' "$cur" ;;
      /*) printf '%s' "$target" ;;
      \~*) printf '%s' "${target/#\~/$HOME}" ;;
      *)  printf '%s' "$cur/$target" ;;
    esac
  else
    printf '%s' "$cur"
  fi
}

# Абсолютный каталог для аргумента -C относительно текущего.
# Args: <c-dir> <current-dir>
cmd_resolve_dir() {
  local dir="$1" cur="$2"
  case "$dir" in
    "") printf '%s' "$cur" ;;
    /*) printf '%s' "$dir" ;;
    \~*) printf '%s' "${dir/#\~/$HOME}" ;;
    *)  printf '%s' "$cur/$dir" ;;
  esac
}
