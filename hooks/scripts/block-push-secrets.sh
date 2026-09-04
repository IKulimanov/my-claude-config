#!/usr/bin/env bash
# PreToolUse / Bash — перед `git push` ищет секреты через trufflehog и блокирует push при находках.
#
# Сканируем НЕ весь рабочий каталог, а только коммиты, которых ещё нет на сервере. Иначе хук
# ругается на то, что давно лежит в истории и уже прошло ревью: на этом репозитории полный скан
# находил два примера строк подключения из документации и блокировал каждый push.
# Если апстрима нет (новая ветка, нет remote) — скан всего каталога, это осознанно строже.
#
# Файл `.trufflehogignore` в корне репозитория (по строке-regex на путь) исключает пути из скана.
# Если trufflehog не установлен — пишем в blocks.jsonl запись kind:"scan-skipped", чтобы отсутствие
# защиты было видно в аудите, а не выглядело как чистый результат.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"

INPUT=$(hook_read_input)
CMD=$(hook_field "$INPUT" '.tool_input.command' '')

if [ -z "$CMD" ]; then
  exit 0
fi

if [[ ! "$CMD" =~ ^[[:space:]]*git[[:space:]]+push ]]; then
  exit 0
fi

CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")
SESSION=$(hook_field "$INPUT" '.session_id')
PROJECT=$(hook_project_name "$CWD")

if ! command -v trufflehog >/dev/null 2>&1; then
  echo "[hook] trufflehog не установлен — сканирование секретов пропущено (brew install trufflehog)." >&2
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg sid "$SESSION" --arg cwd "$CWD" --arg proj "$PROJECT" \
    '{ts:$ts, kind:"scan-skipped", reason:"trufflehog not installed", session:$sid, project:$proj, cwd:$cwd}')"
  exit 0
fi

EXCLUDE_ARGS=()   # bash 3.2 на macOS + set -u: пустой массив разворачиваем через ${a[@]+"${a[@]}"}
if [ -f "$CWD/.trufflehogignore" ]; then
  EXCLUDE_ARGS=(--exclude-paths "$CWD/.trufflehogignore")
fi

# База сравнения: апстрим текущей ветки, иначе одноимённая ветка на origin, иначе HEAD у origin.
BASE=""
for ref in '@{upstream}' "origin/$(git -C "$CWD" rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)" 'origin/HEAD'; do
  if BASE=$(git -C "$CWD" rev-parse --verify --quiet "$ref^{commit}" 2>/dev/null) && [ -n "$BASE" ]; then
    break
  fi
  BASE=""
done

if [ -n "$BASE" ]; then
  SCOPE="коммиты после ${BASE:0:8}"
  SCAN_OUT=$(trufflehog git "file://$CWD" --no-update --no-verification --json \
    --since-commit "$BASE" ${EXCLUDE_ARGS[@]+"${EXCLUDE_ARGS[@]}"} 2>/dev/null || true)
else
  SCOPE="весь каталог (апстрим не найден)"
  SCAN_OUT=$(trufflehog filesystem --no-update --no-verification --json \
    "$CWD" ${EXCLUDE_ARGS[@]+"${EXCLUDE_ARGS[@]}"} 2>/dev/null || true)
fi

# Пустые строки в выводе не считаем находками.
SCAN_OUT=$(printf '%s' "$SCAN_OUT" | grep -v '^[[:space:]]*$' || true)

if [ -n "$SCAN_OUT" ]; then
  COUNT=$(printf '%s\n' "$SCAN_OUT" | wc -l | tr -d ' ')
  # Где именно — иначе непонятно, что смотреть; без этого хук просто мешает.
  WHERE=$(printf '%s\n' "$SCAN_OUT" | jq -r '
      [.DetectorName,
       (.SourceMetadata.Data.Git.file // .SourceMetadata.Data.Filesystem.file // "?"),
       (.SourceMetadata.Data.Git.line // .SourceMetadata.Data.Filesystem.line // "?" | tostring)]
      | "\(.[0]) в \(.[1]):\(.[2])"' 2>/dev/null | sort -u | head -5 | tr '\n' '; ')

  hook_deny "Blocked: trufflehog нашёл $COUNT возможных секрет(ов). Область: $SCOPE. Где: ${WHERE:-не определено}. Проверь и почисти перед push; ложные срабатывания добавь в .trufflehogignore."
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg sid "$SESSION" --arg cwd "$CWD" --arg proj "$PROJECT" \
    --arg n "$COUNT" --arg where "$WHERE" --arg scope "$SCOPE" \
    '{ts:$ts, kind:"push-secrets", session:$sid, project:$proj, cwd:$cwd, found:($n|tonumber), scope:$scope, where:$where}')"
  exit 0
fi

exit 0
