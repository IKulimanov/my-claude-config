#!/usr/bin/env bash
# Печатает описание правила Sonar: название, серьёзность и качество (MQR), текст без HTML.
#
#   sonar-rule.sh <ruleKey>      # например nurtelecomconventionjavarules:LANG-410 или java:S1192
# Нужны SONAR_HOST_URL и SONAR_TOKEN в окружении.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/../lib/sonar-lib.sh"

[ $# -eq 1 ] || { echo "Usage: $(basename "$0") <ruleKey>" >&2; exit 1; }
sonar_require_env

RESP=$(sonar_get "api/rules/show?key=$1")
jq -r '.rule | "# \(.key) — \(.name)", "Серьёзность: \(.impacts[0].severity // .severity // "-") · Качество: \(.impacts[0].softwareQuality // .type // "-")", ""' <<<"$RESP"
jq -r '.rule.htmlDesc // .rule.mdDesc // ""' <<<"$RESP" \
  | perl -pe 's#</(p|li|h[1-6]|pre|div)>#\n#g; s#<br\s*/?>#\n#g; s#<[^>]+>##g; s#&lt;#<#g; s#&gt;#>#g; s#&amp;#&#g; s#&quot;#"#g; s#&nbsp;# #g' \
  | sed -E 's/[[:space:]]+$//' | cat -s
