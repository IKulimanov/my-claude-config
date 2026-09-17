#!/usr/bin/env bash
# Создаёт каркас проекта проектирования из шаблонов плейбука:
#   docs/projects/<project-name>/{00-brief.md,01-design.md,02-plan.md,adr/,options/,assets/}
# Идемпотентен: существующие файлы не трогает. Печатает путь каталога.
#
# Использование:
#   design-init.sh [-n|--dry-run] <project-name>
# Имя — по playbook/project-naming.md: строчные латинские буквы, цифры, дефис.
# DESIGN_PROJECTS_ROOT переопределяет корень (по умолчанию docs/projects репозитория конфига).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATES="$ROOT_DIR/playbook/templates"

usage() {
  echo "Usage: $(basename "$0") [-n|--dry-run] <project-name>" >&2
  exit 1
}

DRY=0
NAME=""
for arg in "$@"; do
  case "$arg" in
    -n|--dry-run) DRY=1 ;;
    -*) usage ;;
    *) [ -z "$NAME" ] || usage; NAME="$arg" ;;
  esac
done
[ -n "$NAME" ] || usage
if ! [[ "$NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Имя проекта — строчные латинские буквы, цифры и дефис (playbook/project-naming.md): «$NAME»" >&2
  exit 1
fi

PROJECTS_ROOT="${DESIGN_PROJECTS_ROOT:-$ROOT_DIR/docs/projects}"
DIR="$PROJECTS_ROOT/$NAME"
DATE=$(date +%Y-%m-%d)

FILES="00-brief.md:brief-template.md 01-design.md:design-template.md 02-plan.md:project-plan-template.md"
SUBDIRS="adr options assets"

for pair in $FILES; do
  tpl="$TEMPLATES/${pair#*:}"
  [ -f "$tpl" ] || { echo "Нет шаблона: $tpl" >&2; exit 1; }
done

if [ "$DRY" = 1 ]; then
  echo "would create: $DIR"
  for pair in $FILES; do
    [ -e "$DIR/${pair%%:*}" ] && echo "  keep   ${pair%%:*}" || echo "  create ${pair%%:*} (из ${pair#*:})"
  done
  for d in $SUBDIRS; do echo "  mkdir  $d/"; done
  exit 0
fi

mkdir -p "$DIR"
for d in $SUBDIRS; do mkdir -p "$DIR/$d"; done
for pair in $FILES; do
  target="$DIR/${pair%%:*}"
  [ -e "$target" ] && continue
  sed -e "s/{{PROJECT}}/$NAME/g" -e "s/{{DATE}}/$DATE/g" "$TEMPLATES/${pair#*:}" > "$target"
done

printf '%s\n' "$DIR"
