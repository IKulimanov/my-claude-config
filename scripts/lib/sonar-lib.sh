#!/usr/bin/env bash
# Общие функции скриптов Sonar: HTTP через curl, постраничная выборка issues, отчёт в формате MQR.
# Требует SONAR_HOST_URL и SONAR_TOKEN в окружении (токен нигде не сохраняется).
# SONAR_OWN_RULES_PREFIX — репозиторий собственных правил команды (по умолчанию nurtelecomconventionjavarules).

SONAR_OWN_RULES_PREFIX="${SONAR_OWN_RULES_PREFIX:-nurtelecomconventionjavarules}"

sonar_require_env() {
  [ -n "${SONAR_HOST_URL:-}" ] || { echo "Нужна переменная SONAR_HOST_URL (адрес сервера Sonar)" >&2; return 1; }
  [ -n "${SONAR_TOKEN:-}" ] || { echo "Нужна переменная SONAR_TOKEN (токен пользователя с правом Browse)" >&2; return 1; }
}

# GET <api/path?query> → тело ответа
sonar_get() {
  curl -sS -f -u "$SONAR_TOKEN:" "${SONAR_HOST_URL%/}/$1"
}

# POST <api/path> <form-data> → тело ответа
sonar_post() {
  curl -sS -f -u "$SONAR_TOKEN:" -X POST --data "$2" "${SONAR_HOST_URL%/}/$1"
}

# Все нерешённые issues проекта (постранично). Args: <projectKey> [branch] → JSON-массив
sonar_fetch_issues() {
  local key="$1" branch="${2:-}" page=1 all='[]' resp total have query
  while :; do
    query="api/issues/search?components=$key&resolved=false&ps=500&p=$page"
    [ -n "$branch" ] && query="$query&branch=$branch"
    resp=$(sonar_get "$query") || return 1
    all=$(jq -c --argjson acc "$all" '$acc + (.issues // [])' <<<"$resp")
    total=$(jq -r '.paging.total // .total // 0' <<<"$resp")
    have=$(jq 'length' <<<"$all")
    [ "$have" -ge "$total" ] && break
    page=$((page + 1))
    [ "$page" -gt 40 ] && break
  done
  printf '%s' "$all"
}

# Отчёт по issues. Args: <issues-json> <projectKey> [files-json-array — фильтр по путям, "" = все]
sonar_format_report() {
  local issues="$1" key="$2" files="${3:-}"
  jq -r --arg key "$key" --arg own "$SONAR_OWN_RULES_PREFIX" --argjson files "${files:-null}" '
    def sev: (.impacts[0].severity // .severity // "MEDIUM");
    def quality: (.impacts[0].softwareQuality // .type // "-");
    def path: (.component | sub("^" + ($key | gsub("\\."; "\\.")) + ":"; ""));
    def rank: {BLOCKER: 0, HIGH: 1, MEDIUM: 2, LOW: 3, INFO: 4}[sev] // 5;
    def line: "- \(path):\(.line // 0) · \(.rule) · \(sev) · \(quality) · \(.message)";
    [ .[] | select($files == null or (path as $p | $files | index($p) != null)) ] as $all
    | ($all | map(select(.rule | startswith($own + ":")))) as $ownIssues
    | ($all | map(select(.rule | startswith($own + ":") | not)) | sort_by(rank, path, .line)) as $builtin
    | ($all | map(sev) | group_by(.) | map({(.[0]): length}) | add // {}) as $bySev
    | "# Sonar: \($key)",
      "Всего: \($all | length) (собственные правила: \($ownIssues | length); BLOCKER \($bySev.BLOCKER // 0), HIGH \($bySev.HIGH // 0), MEDIUM \($bySev.MEDIUM // 0), LOW \($bySev.LOW // 0), INFO \($bySev.INFO // 0))",
      "",
      "## Собственные правила команды",
      (if ($ownIssues | length) == 0 then "- нет" else ($ownIssues | sort_by(path, .line) | .[] | line) end),
      "",
      "## Встроенные правила",
      (if ($builtin | length) == 0 then "- нет" else ($builtin | .[] | line) end)
  ' <<<"$issues"
}

# Изменённые файлы репозитория относительно базы: дифф ветки, незакоммиченное, новые. → JSON-массив путей
sonar_changed_files_json() {
  local base="$1"
  { git diff --name-only "$base"...HEAD 2>/dev/null || true
    git diff --name-only HEAD 2>/dev/null || true
    git ls-files --others --exclude-standard; } | sort -u | jq -R . | jq -s -c .
}
