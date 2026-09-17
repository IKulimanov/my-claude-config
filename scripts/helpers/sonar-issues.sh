#!/usr/bin/env bash
# Печатает нерешённые issues проекта Sonar в формате MQR: сначала собственные правила команды,
# затем встроенные по серьёзности.
#
#   sonar-issues.sh <projectKey> [--branch <имя>] [--files a.java,b.java]
# Нужны SONAR_HOST_URL и SONAR_TOKEN в окружении.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/sonar-lib.sh"

usage() { echo "Usage: $(basename "$0") <projectKey> [--branch <name>] [--files a,b]" >&2; exit 1; }

KEY=""; BRANCH=""; FILES=""
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --files) FILES="$2"; shift 2 ;;
    -*) usage ;;
    *) [ -z "$KEY" ] || usage; KEY="$1"; shift ;;
  esac
done
[ -n "$KEY" ] || usage
sonar_require_env

ISSUES=$(sonar_fetch_issues "$KEY" "$BRANCH")
FILTER=""
[ -n "$FILES" ] && FILTER=$(printf '%s' "$FILES" | tr ',' '\n' | jq -R . | jq -s -c .)
sonar_format_report "$ISSUES" "$KEY" "$FILTER"
