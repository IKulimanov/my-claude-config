#!/usr/bin/env bash
#
# Ставит launchd-джоб недельной аналитики Claude Code (run-weekly-review.sh).
# Расписание: суббота 09:00 + страховочные срабатывания вс/пн 10:00 (launchd
# не навёрстывает пропуски при выключенной машине; лишние запуски — no-op,
# потому что runner делает fast-exit, если отчёт недели уже есть).
#
# По умолчанию — dry-run (ничего не меняет). Реально применить — флаг --apply.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

LABEL="com.claude-config.weekly-analytics"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/automations"
LOG_FILE="$LOG_DIR/claude-weekly-analytics.launchd.log"

APPLY=0
COMMAND=""

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  status              Показать состояние джоба (plist + launchctl)
  install             Установить/переустановить launchd-джоб (по умолчанию dry-run)
  uninstall           Снять джоб и удалить plist

Options:
  --apply             Реально применить. Без этого — dry-run, ничего не меняем.
  -h, --help

Проверка без ожидания субботы:
  launchctl kickstart gui/\$(id -u)/$LABEL
Лог: $LOG_FILE
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    status|install|uninstall)
      [ -n "$COMMAND" ] && { echo "Multiple commands given" >&2; exit 1; }
      COMMAND="$1"; shift ;;
    --apply) APPLY=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -z "$COMMAND" ] && usage

[ "$(uname)" = "Darwin" ] || { echo "Только macOS (launchd)" >&2; exit 1; }

prefix() { [ "$APPLY" -eq 1 ] && echo "" || echo "[dry-run] "; }

do_or_echo() {
  if [ "$APPLY" -eq 1 ]; then "$@"; else echo "$(prefix)$*"; fi
}

render_plist() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$ROOT_DIR/scripts/run-weekly-review.sh</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$ROOT_DIR</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PATH</key>
    <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
  </dict>
  <key>StartCalendarInterval</key>
  <array>
    <dict><key>Weekday</key><integer>6</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Weekday</key><integer>0</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
    <dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer></dict>
  </array>
  <key>StandardOutPath</key>
  <string>$LOG_FILE</string>
  <key>StandardErrorPath</key>
  <string>$LOG_FILE</string>
</dict>
</plist>
EOF
}

case "$COMMAND" in
  status)
    echo "Label:  $LABEL"
    echo "Plist:  $PLIST $([ -f "$PLIST" ] && echo '(есть)' || echo '(нет)')"
    echo "Runner: $ROOT_DIR/scripts/run-weekly-review.sh"
    echo "Лог:    $LOG_FILE"
    if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
      echo "launchd: загружен"
      launchctl print "gui/$(id -u)/$LABEL" 2>/dev/null | grep -E 'state|last exit' | sed 's/^/  /' || true
    else
      echo "launchd: не загружен"
    fi
    ;;

  install)
    echo "$(prefix)Установка $LABEL (Сб 09:00 + страховка Вс/Пн 10:00)"
    if [ -f "$PLIST" ]; then
      backup_dir="$CLAUDE_HOME/backups/weekly-analytics-$(date +%s)"
      echo "$(prefix)Бэкап существующего plist -> $backup_dir/"
      do_or_echo mkdir -p "$backup_dir"
      do_or_echo cp "$PLIST" "$backup_dir/"
    fi
    do_or_echo mkdir -p "$LOG_DIR" "$(dirname "$PLIST")"
    if [ "$APPLY" -eq 1 ]; then
      render_plist > "$PLIST"
      echo "Записан: $PLIST"
      # bootout может ругаться, если джоб не был загружен — это не ошибка.
      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "$PLIST"
      echo "Загружен: gui/$(id -u)/$LABEL"
      echo "Проверка без ожидания субботы: launchctl kickstart gui/$(id -u)/$LABEL"
    else
      echo "[dry-run] Записать plist -> $PLIST"
      echo "[dry-run] launchctl bootout + bootstrap gui/$(id -u)"
    fi
    ;;

  uninstall)
    echo "$(prefix)Снятие $LABEL"
    if [ "$APPLY" -eq 1 ]; then
      launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
      if [ -f "$PLIST" ]; then
        backup_dir="$CLAUDE_HOME/backups/weekly-analytics-$(date +%s)"
        mkdir -p "$backup_dir"
        mv "$PLIST" "$backup_dir/"
        echo "Plist перемещён в $backup_dir/"
      fi
    else
      echo "[dry-run] launchctl bootout gui/$(id -u)/$LABEL"
      echo "[dry-run] Переместить $PLIST в бэкап"
    fi
    ;;
esac
