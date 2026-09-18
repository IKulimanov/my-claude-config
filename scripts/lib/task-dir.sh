#!/usr/bin/env bash
# Где лежат артефакты задачи: <корень репозитория>/.claude/tasks/<ключ>/ (каталог игнорируется глобальным
# excludes git, который ставит setup-global.sh). Ключ — из имени ветки: Jira-ID, если он есть
# (feature/ORSP-1234-export → ORSP-1234), иначе имя ветки без типового префикса и со слэшами, заменёнными
# на дефис (feature/export-csv → export-csv, release/1.2 → release-1.2). Доработки той же задачи получают
# номер: <ключ>-2, <ключ>-3 …
# Подключение: . "$(dirname "$0")/../lib/task-dir.sh" (из хука: hooks/scripts/../../scripts/lib/task-dir.sh)

TASK_TYPE_PREFIXES='feature|feat|fix|bugfix|hotfix|chore|refactor|docs|task'

# Ключ задачи из имени ветки или явного имени.
task_key() {
  local raw="$1" key
  if [[ "$raw" =~ ([A-Z][A-Z0-9]+-[0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
    return 0
  fi
  key=$(printf '%s' "$raw" | sed -E 's#^('"$TASK_TYPE_PREFIXES"')/##; s#[^A-Za-z0-9._-]+#-#g; s#-+#-#g; s#^[-.]+##; s#[-.]+$##')
  [ -n "$key" ] || key=$(printf '%s' "$raw" | sed -E 's#[^A-Za-z0-9._-]+#-#g; s#-+#-#g; s#^[-.]+##; s#[-.]+$##')
  [ -n "$key" ] || key="task"
  printf '%s' "$key"
}

# Корень репозитория для каталога; вне git — сам каталог. Всегда физический путь.
task_repo_root() {
  local d="${1:-.}"
  git -C "$d" rev-parse --show-toplevel 2>/dev/null || (cd "$d" && pwd -P)
}

# Текущая ветка; вне git или на отсоединённом HEAD — пусто.
task_branch() {
  git -C "$1" symbolic-ref --short -q HEAD 2>/dev/null || true
}

# Последний существующий каталог задачи для ключа (<ключ>, <ключ>-2 …) или пусто.
task_dir_latest() {
  local root="$1" key="$2" best="" max=0 d n
  local base="$root/.claude/tasks/$key"
  [ -d "$base" ] && best="$base"
  for d in "$base"-*; do
    [ -d "$d" ] || continue
    n="${d##*-}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    if [ "$n" -gt "$max" ]; then max="$n"; best="$d"; fi
  done
  printf '%s' "$best"
}

# Следующий свободный каталог задачи: <ключ>, если его ещё нет, иначе <ключ>-N за наибольшим номером.
task_dir_next() {
  local root="$1" key="$2" max=1 d n
  local base="$root/.claude/tasks/$key"
  [ -d "$base" ] || { printf '%s' "$base"; return 0; }
  for d in "$base"-*; do
    [ -d "$d" ] || continue
    n="${d##*-}"
    [[ "$n" =~ ^[0-9]+$ ]] || continue
    if [ "$n" -gt "$max" ]; then max="$n"; fi
  done
  printf '%s' "$base-$((max + 1))"
}
