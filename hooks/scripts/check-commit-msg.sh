#!/usr/bin/env bash
# PreToolUse / Bash — формат сообщения коммита (правило 09, скил git-convention).
# Рабочий проект (cwd под WORK_ROOT из workspace.conf, по умолчанию ~/dev/work): `JIRA-ID: Глагол …` — латинский ключ, русское описание с заглавной.
# Личный проект: `тип(scope): глагол …` — тип из списка, русское описание со строчной.
# Первая строка ≤ 72 символов; трейлеры (Co-Authored-By и подобные) запрещены везде.
# Сообщение берётся из -m/--message (несколько -m допустимы) или из heredoc (-F - / $(cat <<EOF)).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/lib/common.sh"
. "$SCRIPT_DIR/lib/cmdparse.sh"

INPUT=$(hook_read_input)
CMD=$(hook_field "$INPUT" '.tool_input.command' '')
[ -z "$CMD" ] && exit 0
CWD=$(hook_field "$INPUT" '.cwd' "$(pwd)")

# Ищем сегмент с git commit и его эффективный каталог (учитывая cd и -C).
cur_dir="$CWD"
commit_args=""
commit_dir=""
while IFS= read -r seg; do
  [ -z "$seg" ] && continue
  new_dir=$(cmd_apply_cd "$seg" "$cur_dir")
  if [ "$new_dir" != "$cur_dir" ] || [[ "$seg" =~ ^cd([[:space:]]|$) ]]; then
    cur_dir="$new_dir"
    continue
  fi
  rest=$(git_strip "$seg")
  [ -z "$rest" ] && continue
  if [ "$(printf '%s' "$rest" | awk '{print $1}')" = "commit" ]; then
    commit_args=$(printf '%s' "$rest" | sed -E 's/^commit[[:space:]]*//')
    commit_dir=$(cmd_resolve_dir "$(git_c_dir "$seg")" "$cur_dir")
    break
  fi
done < <(cmd_segments "$CMD")
[ -z "$commit_dir" ] && exit 0

deny() {
  hook_deny "$1"
  hook_log "blocks" "$(jq -n --arg ts "$(hook_now)" --arg r "$1" --arg cmd "$(printf '%s' "$CMD" | head -c 300)" \
    --arg sid "$(hook_field "$INPUT" '.session_id')" --arg cwd "$CWD" --arg proj "$(hook_project_name "$CWD")" \
    '{ts:$ts, kind:"commit-msg", decision:"deny", reason:$r, session:$sid, project:$proj, cwd:$cwd, command:$cmd}')"
  exit 0
}

# Сообщение не меняется — проверять нечего.
if [[ "$commit_args" =~ (^|[[:space:]])(--amend|-C|-c|--reuse-message|--reedit-message)([[:space:]]|$) ]] \
   && ! [[ "$commit_args" =~ (^|[[:space:]])(-m|--message|-F|--file)([[:space:]]|=) ]]; then
  exit 0
fi

# Текст сообщения: heredoc имеет приоритет (-F - <<EOF, -m "$(cat <<EOF …)"), иначе значения -m.
MSG=$(printf '%s' "$CMD" | perl -CSD -0777 -ne '
  if (/<<-?[ \t]*(["\x27]?)([A-Za-z_][A-Za-z0-9_]*)\1[^\n]*\n(.*?)\n[ \t]*\2[ \t]*(\n|$)/s) { print $3; exit }
  my @parts;
  while (/(?:-m|--message)(?:=|[ \t]+)(?:"((?:\\.|[^"\\])*)"|\x27([^\x27]*)\x27|([^ \t\n]+))/g) {
    my $v = defined $1 ? $1 : defined $2 ? $2 : $3;
    $v =~ s/\\"/"/g;
    push @parts, $v;
  }
  print join("\n\n", @parts);
')

if [ -z "$MSG" ]; then
  if [[ "$commit_args" =~ (^|[[:space:]])(-F|--file)([[:space:]]|=) ]]; then
    exit 0   # сообщение в файле — не проверяем
  fi
  deny "Коммит без сообщения: редактор недоступен. Укажи сообщение через -m (правило 09)."
fi

# Рабочий проект — под каталогом WORK_ROOT: CLAUDE_WORK_ROOT (тесты) → workspace.conf репозитория конфига
# (CLAUDE_WORKSPACE_CONF задаёт файл для тестов) → $HOME/dev/work. Jira-ID берётся из имени ветки: если он
# там есть, коммит обязан начинаться с того же ID; если ветка без ID — ID не нужен.
WORKSPACE_CONF="${CLAUDE_WORKSPACE_CONF:-$SCRIPT_DIR/../../workspace.conf}"
if [ -n "${CLAUDE_WORK_ROOT:-}" ]; then
  WORK_ROOT="$CLAUDE_WORK_ROOT"
else
  WORK_ROOT="$HOME/dev/work"
  if [ -f "$WORKSPACE_CONF" ]; then
    conf_root=$(sh -c ". '$WORKSPACE_CONF' 2>/dev/null; printf '%s' \"\${WORK_ROOT:-}\"") || conf_root=""
    [ -n "$conf_root" ] && WORK_ROOT="$conf_root"
  fi
fi
if [[ "$commit_dir" == "$WORK_ROOT/"* ]]; then PROJECT_TYPE=work; else PROJECT_TYPE=personal; fi
BRANCH=$(git -C "$commit_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
BRANCH_ID=$(printf '%s' "$BRANCH" | grep -oE '[A-Z][A-Z0-9]+-[0-9]+' | head -1 || true)

VERDICT=$(printf '%s' "$MSG" | PROJECT_TYPE="$PROJECT_TYPE" BRANCH_ID="$BRANCH_ID" perl -CSD -0777 -ne '
  my $type = $ENV{PROJECT_TYPE};
  my $id = $ENV{BRANCH_ID} // "";
  my ($subject) = grep { /\S/ } split /\n/;
  $subject //= "";
  if (/^\s*(co-authored-by|signed-off-by|generated with)\s*:?/mi || /Generated with \[?Claude/i) { print "trailer"; exit }
  if ($subject =~ /^(Merge |Revert ")/) { print "ok"; exit }
  if (length($subject) > 72) { print "long"; exit }
  if ($type eq "work") {
    if ($id ne "") {
      if ($subject =~ /^\Q$id\E: (?=\p{Cyrillic})/) { print "ok" }
      elsif ($subject =~ /^[A-Z][A-Z0-9]+-\d+: /) { print "work-id-mismatch" }
      else { print "work-format" }
    } else {
      print(($subject =~ /^([A-Z][A-Z0-9]+-\d+: )?(?=\p{Cyrillic})/) ? "ok" : "work-format");
    }
    exit
  }
  print(($subject =~ /^(feat|fix|docs|refactor|test|chore|build|ci|perf)(\([a-z0-9._\/-]+\))?: (?=\p{Cyrillic})\p{Ll}/) ? "ok" : "personal-format");
')

case "$VERDICT" in
  ok) exit 0 ;;
  trailer) deny "Трейлеры в коммитах запрещены (Co-Authored-By, Signed-off-by, Generated with) — убери их (правило 09)." ;;
  long) deny "Первая строка коммита длиннее 72 символов — сократи (правило 09)." ;;
  work-id-mismatch) deny "Jira-ID в коммите не совпадает с веткой ($BRANCH_ID): первая строка должна начинаться с «$BRANCH_ID: » (правило 09)." ;;
  work-format) deny "Формат коммита рабочего проекта: «${BRANCH_ID:-ORSP-1234}: Добавить ретрай отправки в Kafka» — Jira-ID из имени ветки, двоеточие, описание по-русски с глагола в инфинитиве; если в ветке нет Jira-ID — «Добавить …» без ID (правило 09)." ;;
  personal-format) deny "Формат коммита личного проекта: «feat(api): добавить ретрай отправки в Kafka» — тип из feat|fix|docs|refactor|test|chore|build|ci|perf, scope по желанию, глагол в инфинитиве со строчной, по-русски (правило 09)." ;;
  *) exit 0 ;;
esac
