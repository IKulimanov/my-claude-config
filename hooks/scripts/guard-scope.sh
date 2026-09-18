#!/usr/bin/env bash
# PreToolUse / Edit|Write|MultiEdit — границы задачи. Пока в <корень>/.claude/tasks/<ключ>/agent/scope.txt
# статус active, запись в файл репозитория вне списка требует подтверждения (ask): исполнитель не
# расползается за план. Артефакты .claude/tasks/, файлы вне репозитория, ветка без задачи и завершённый
# scope проходят. Bash-записи здесь не проверяются — их держат guard-paths и guard-tests.
# Ключ задачи — из ветки (scripts/lib/task-dir.sh), сверка со списком — scripts/helpers/scope.sh.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/../../scripts/lib/task-dir.sh"
SCOPE="$SCRIPT_DIR/../../scripts/helpers/scope.sh"

INPUT=$(hook_read_input)
TOOL=$(hook_field "$INPUT" '.tool_name')
case "$TOOL" in Edit|Write|MultiEdit) ;; *) exit 0 ;; esac
TARGET=$(hook_field "$INPUT" '.tool_input.file_path' '')
[ -n "$TARGET" ] || exit 0
CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")
ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null) || exit 0

# Абсолютный физический путь цели. Файла и его каталога может ещё не быть (Write), поэтому раскрываем
# самого глубокого существующего предка, остаток добавляем текстом.
abs_path() {
  local p="$1" rest=""
  case "$p" in /*) ;; *) p="$CWD/$p" ;; esac
  while [ ! -d "$p" ]; do
    rest="/$(basename "$p")$rest"
    p=$(dirname "$p")
  done
  printf '%s%s' "$(cd "$p" && pwd -P)" "$rest"
}
ABS=$(abs_path "$TARGET")
case "$ABS" in "$ROOT"/*) REL="${ABS#"$ROOT"/}" ;; *) exit 0 ;; esac
case "$REL" in .claude/tasks/*) exit 0 ;; esac

BRANCH=$(task_branch "$ROOT")
[ -n "$BRANCH" ] || exit 0
DIR=$(task_dir_latest "$ROOT" "$(task_key "$BRANCH")")
[ -n "$DIR" ] || exit 0
"$SCOPE" "$DIR" check "$REL" && exit 0

TASK=$(basename "$DIR")
hook_ask "Файл вне scope задачи $TASK: $REL. Правка нужна по плану — подтверди и добавь путь (scope.sh $DIR add $REL); иначе это вопрос [!] оператору, а не правка."
hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg tool "$TOOL" --arg rel "$REL" --arg task "$TASK" \
  --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" \
  --arg agent "$(hook_field "$INPUT" '.agent_type' '')" \
  '{ts:$ts, kind:"scope", decision:"ask", tool:$tool, session:$sid, project:$proj, cwd:$cwd, target:$rel, task:$task, agent:$agent}')"
exit 0
