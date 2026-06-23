#!/usr/bin/env bash
#
# Разворачивает my-claude-config глобально в ~/.claude/.
# Назначение — на новом устройстве: склонировал репо → запустил → всё работает.
#
# По умолчанию — dry-run (ничего не меняет). Чтобы реально применить — флаг --apply.
# Все существующие файлы/папки бэкапятся в ~/.claude/backups/global-install-<timestamp>/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

# ─── Defaults ────────────────────────────────────────────────────────────────
APPLY=0
MODE="symlink"          # symlink | copy
COMPONENTS="skills,agents,commands,hooks,claude-md,output-styles,statusline"
COMMAND=""

# ─── Args ────────────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  status              Показать что установлено сейчас vs что встанет
  install             Установить компоненты глобально (по умолчанию dry-run)
  uninstall           Удалить symlinks/файлы, созданные нами

Options:
  --apply             Реально применить. Без этого — dry-run, ничего не меняем.
  --copy              Использовать copy вместо symlink (по умолчанию: symlink)
  --components LIST   Список компонентов через запятую (default: $COMPONENTS)
                      Доступно: skills,agents,commands,hooks,claude-md,output-styles,statusline
  --config-dir DIR    Откуда брать (default: $ROOT_DIR)
  -h, --help

Examples:
  $(basename "$0") status
  $(basename "$0") install                          # dry-run, покажет что сделает
  $(basename "$0") install --apply                  # реально применит
  $(basename "$0") install --components skills,agents --apply
  $(basename "$0") install --copy --apply           # вместо symlink — копировать
  $(basename "$0") uninstall --apply                # удалить установленное

Идемпотентность: повторный install переустанавливает с новым бэкапом.
EOF
  exit 0
}

while [ $# -gt 0 ]; do
  case "$1" in
    status|install|uninstall)
      [ -n "$COMMAND" ] && { echo "Multiple commands given" >&2; exit 1; }
      COMMAND="$1"; shift ;;
    --apply) APPLY=1; shift ;;
    --copy)  MODE="copy"; shift ;;
    --components)
      [ $# -lt 2 ] && { echo "--components needs a value" >&2; exit 1; }
      COMPONENTS="$2"; shift 2 ;;
    --config-dir)
      [ $# -lt 2 ] && { echo "--config-dir needs a value" >&2; exit 1; }
      ROOT_DIR="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

[ -z "$COMMAND" ] && usage

# ─── Pre-flight ──────────────────────────────────────────────────────────────
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq required. Install: brew install jq (macOS) or apt install jq (Linux)" >&2
  exit 1
fi

if [ ! -d "$ROOT_DIR" ]; then
  echo "Error: config dir not found: $ROOT_DIR" >&2
  exit 1
fi

for comp in $(echo "$COMPONENTS" | tr ',' ' '); do
  case "$comp" in
    skills|agents|commands|hooks|claude-md|output-styles|statusline) ;;
    *) echo "Error: unknown component '$comp'. Valid: skills,agents,commands,hooks,claude-md,output-styles,statusline" >&2; exit 1 ;;
  esac
done

# ─── Helpers ─────────────────────────────────────────────────────────────────

# Печатает префикс для шага: [DRY] или [APPLY]
prefix() {
  if [ "$APPLY" -eq 1 ]; then echo "[apply]"; else echo "[dry ]"; fi
}

# Действие, которое в dry-run только печатается, а с --apply реально выполняется
do_or_echo() {
  echo "$(prefix) $*"
  if [ "$APPLY" -eq 1 ]; then
    eval "$@"
  fi
}

# Создать бэкап существующего пути в ~/.claude/backups/global-install-<ts>/
# Возвращает путь бэкапа (для информации).
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$CLAUDE_HOME/backups/global-install-$TIMESTAMP"

backup_if_exists() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$APPLY" -eq 1 ]; then
      mkdir -p "$BACKUP_DIR"
      mv "$target" "$BACKUP_DIR/$(basename "$target")"
    fi
    echo "$(prefix) backup: $target → $BACKUP_DIR/"
    return 0
  fi
  return 1
}

# Установить компонент: symlink или copy.
install_component() {
  local name="$1"          # skills | agents | commands
  local src="$ROOT_DIR/$name"
  local dst="$CLAUDE_HOME/$name"

  if [ ! -d "$src" ]; then
    echo "$(prefix) skip $name — source not found: $src"
    return
  fi

  backup_if_exists "$dst" || true

  if [ "$MODE" = "copy" ]; then
    do_or_echo "cp -R '$src' '$dst'"
  else
    do_or_echo "ln -s '$src' '$dst'"
  fi
}

install_hooks() {
  local hook_script="$ROOT_DIR/scripts/install-hooks.sh"
  if [ ! -x "$hook_script" ]; then
    echo "$(prefix) skip hooks — install-hooks.sh missing or not executable"
    return
  fi
  if [ "$APPLY" -eq 1 ]; then
    echo "$(prefix) delegating to install-hooks.sh --write"
    "$hook_script" --write
  else
    echo "$(prefix) would run: $hook_script --write  (merges hooks into ~/.claude/settings.json with backup)"
  fi
}

# Сгенерировать ~/.claude/CLAUDE.md с @import каждого rules/*.md.
# Пишем только между маркерами — ручной контент пользователя сохраняется.
install_claude_md() {
  local dst="$CLAUDE_HOME/CLAUDE.md"
  local rules_dir="$ROOT_DIR/rules"
  local begin="<!-- BEGIN my-claude-config (managed) -->"
  local end="<!-- END my-claude-config (managed) -->"

  if [ ! -d "$rules_dir" ]; then
    echo "$(prefix) skip claude-md — rules dir not found: $rules_dir"
    return
  fi

  local count
  count=$(ls -1 "$rules_dir"/*.md 2>/dev/null | wc -l | tr -d ' ')
  echo "$(prefix) claude-md → $dst (@import $count rules)"

  if [ "$APPLY" -ne 1 ]; then return 0; fi

  mkdir -p "$CLAUDE_HOME"

  # Собираем управляемый блок: маркеры + @import всех rules/*.md по порядку имён.
  local block="$begin"$'\n'
  block+="# Auto-generated by setup-global.sh from my-claude-config/rules/. Do not edit by hand."$'\n'
  local f
  for f in "$rules_dir"/*.md; do
    [ -e "$f" ] || continue
    block+="@$f"$'\n'
  done
  block+="$end"

  if [ -f "$dst" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$dst" "$BACKUP_DIR/CLAUDE.md"
    # Вырезаем старый управляемый блок (если был), сохраняя остальной контент.
    local tmp; tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
      $0==b {skip=1}
      skip==0 {print}
      $0==e {skip=0; next}
    ' "$dst" > "$tmp"
    printf '%s\n' "$block" >> "$tmp"
    mv "$tmp" "$dst"
  else
    printf '%s\n' "$block" > "$dst"
  fi
}

# Установить outputStyle=personal в ~/.claude/settings.json (вызывается после hooks).
set_output_style() {
  local settings="$CLAUDE_HOME/settings.json"
  local style="personal"
  echo "$(prefix) settings.json: outputStyle=$style"

  if [ "$APPLY" -ne 1 ]; then return 0; fi

  mkdir -p "$CLAUDE_HOME"
  if [ -f "$settings" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$settings" "$BACKUP_DIR/settings.json.before-outputstyle"
    local tmp; tmp="$(mktemp)"
    jq --arg s "$style" '.outputStyle = $s' "$settings" > "$tmp" && mv "$tmp" "$settings"
  else
    printf '{\n  "outputStyle": "%s"\n}\n' "$style" > "$settings"
  fi
}

# Установить файл statusline.sh в ~/.claude/statusline.sh (symlink или copy).
install_statusline_file() {
  local src="$ROOT_DIR/statusline/statusline.sh"
  local dst="$CLAUDE_HOME/statusline.sh"

  if [ ! -f "$src" ]; then
    echo "$(prefix) skip statusline — source not found: $src"
    return
  fi

  backup_if_exists "$dst" || true

  if [ "$MODE" = "copy" ]; then
    do_or_echo "cp '$src' '$dst'"
  else
    do_or_echo "ln -s '$src' '$dst'"
  fi
}

# Прописать .statusLine в ~/.claude/settings.json (вызывается после hooks, как outputStyle).
set_statusline() {
  local settings="$CLAUDE_HOME/settings.json"
  local cmd="$CLAUDE_HOME/statusline.sh"
  echo "$(prefix) settings.json: statusLine → $cmd"

  if [ "$APPLY" -ne 1 ]; then return 0; fi

  mkdir -p "$CLAUDE_HOME"
  if [ -f "$settings" ]; then
    mkdir -p "$BACKUP_DIR"
    cp "$settings" "$BACKUP_DIR/settings.json.before-statusline"
    local tmp; tmp="$(mktemp)"
    jq --arg c "$cmd" '.statusLine = {type: "command", command: $c, padding: 0}' "$settings" > "$tmp" && mv "$tmp" "$settings"
  else
    jq -n --arg c "$cmd" '{statusLine: {type: "command", command: $c, padding: 0}}' > "$settings"
  fi
}

# ─── Commands ────────────────────────────────────────────────────────────────

cmd_status() {
  echo "Claude config status"
  echo "  config dir : $ROOT_DIR"
  echo "  ~/.claude  : $CLAUDE_HOME"
  echo
  printf '%-12s %-10s %s\n' "Component" "State" "Target"
  printf '%-12s %-10s %s\n' "─────────" "─────" "──────"
  for name in skills agents commands output-styles; do
    local dst="$CLAUDE_HOME/$name"
    local src="$ROOT_DIR/$name"
    local state target
    if [ -L "$dst" ]; then
      target=$(readlink "$dst")
      if [ "$target" = "$src" ]; then
        state="linked-ok"
      else
        state="linked-foreign"
      fi
    elif [ -d "$dst" ]; then
      state="dir-present"; target="(custom directory, not from config)"
    else
      state="missing"; target="—"
    fi
    printf '%-12s %-10s %s\n' "$name" "$state" "$target"
  done

  # hooks
  local settings="$CLAUDE_HOME/settings.json"
  local hooks_state
  if [ -f "$settings" ] && jq -e '.hooks' "$settings" >/dev/null 2>&1; then
    hooks_state="present"
  else
    hooks_state="missing"
  fi
  printf '%-12s %-10s %s\n' "hooks" "$hooks_state" "in $settings"

  # claude-md: глобальная память, импортирующая rules/
  local cmd_file="$CLAUDE_HOME/CLAUDE.md" cmd_state
  if [ -f "$cmd_file" ] && grep -qF "my-claude-config (managed)" "$cmd_file" 2>/dev/null; then
    cmd_state="present"
  else
    cmd_state="missing"
  fi
  printf '%-12s %-10s %s\n' "claude-md" "$cmd_state" "$cmd_file"

  # outputStyle в settings.json
  local os_state="missing"
  if [ -f "$settings" ] && [ "$(jq -r '.outputStyle // empty' "$settings" 2>/dev/null)" = "personal" ]; then
    os_state="personal"
  fi
  printf '%-12s %-10s %s\n' "outputStyle" "$os_state" "in $settings"

  # statusline: файл statusline.sh + .statusLine в settings.json
  local sl_dst="$CLAUDE_HOME/statusline.sh" sl_src="$ROOT_DIR/statusline/statusline.sh" sl_state sl_target
  if [ -L "$sl_dst" ]; then
    sl_target=$(readlink "$sl_dst")
    [ "$sl_target" = "$sl_src" ] && sl_state="linked-ok" || sl_state="linked-foreign"
  elif [ -f "$sl_dst" ]; then
    sl_state="file-present"; sl_target="(real file, not from config)"
  else
    sl_state="missing"; sl_target="—"
  fi
  if [ -f "$settings" ] && jq -e '.statusLine' "$settings" >/dev/null 2>&1; then
    sl_state="$sl_state +cfg"
  fi
  printf '%-12s %-10s %s\n' "statusline" "$sl_state" "$sl_target"
  echo
  echo "Run '$(basename "$0") install' to see install plan, add --apply to execute."
}

cmd_install() {
  echo "Install plan ($(prefix)):"
  echo "  source : $ROOT_DIR"
  echo "  target : $CLAUDE_HOME"
  echo "  mode   : $MODE"
  echo "  comps  : $COMPONENTS"
  [ "$APPLY" -eq 1 ] && echo "  backup : $BACKUP_DIR" || echo "  backup : (would create on apply)"
  echo

  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$CLAUDE_HOME"
  fi

  for comp in $(echo "$COMPONENTS" | tr ',' ' '); do
    case "$comp" in
      skills|agents|commands|output-styles) install_component "$comp" ;;
      hooks)                                 install_hooks ;;
      claude-md)                             install_claude_md ;;
      statusline)                            install_statusline_file ;;
    esac
  done
  # Настройки в settings.json ставим ПОСЛЕ hooks, чтобы merge хуков не затёр их.
  case ",$COMPONENTS," in
    *,output-styles,*) set_output_style ;;
  esac
  case ",$COMPONENTS," in
    *,statusline,*) set_statusline ;;
  esac

  echo
  if [ "$APPLY" -eq 1 ]; then
    echo "Done. Verify:"
    echo "  $(basename "$0") status"
    echo "  ls -la $CLAUDE_HOME/{skills,agents,commands}"
    echo "  claude --debug   # увидишь как срабатывают хуки"
    if [ -d "$BACKUP_DIR" ]; then
      echo
      echo "Бэкап перенесённых файлов: $BACKUP_DIR"
      echo "Откатить: $(basename "$0") uninstall --apply"
    fi
  else
    echo "Это был dry-run. Чтобы реально применить:"
    echo "  $(basename "$0") install --apply"
  fi
}

cmd_uninstall() {
  echo "Uninstall plan ($(prefix)):"
  echo "  target : $CLAUDE_HOME"
  echo

  for name in skills agents commands output-styles; do
    local dst="$CLAUDE_HOME/$name"
    if [ -L "$dst" ]; then
      local target
      target=$(readlink "$dst")
      if [ "$target" = "$ROOT_DIR/$name" ]; then
        do_or_echo "rm '$dst'"
      else
        echo "$(prefix) skip $name — symlink points to '$target', not ours"
      fi
    elif [ -d "$dst" ]; then
      echo "$(prefix) skip $name — is a real directory, not installed by us. Trogai vruchnuiu."
    else
      echo "$(prefix) skip $name — not present"
    fi
  done

  # statusline: убрать наш symlink на statusline.sh (реальный файл не трогаем)
  local sl_dst="$CLAUDE_HOME/statusline.sh"
  if [ -L "$sl_dst" ]; then
    local sl_target
    sl_target=$(readlink "$sl_dst")
    if [ "$sl_target" = "$ROOT_DIR/statusline/statusline.sh" ]; then
      do_or_echo "rm '$sl_dst'"
    else
      echo "$(prefix) skip statusline.sh — symlink points to '$sl_target', not ours"
    fi
  elif [ -f "$sl_dst" ]; then
    echo "$(prefix) skip statusline.sh — is a real file, not installed by us. Trogai vruchnuiu."
  else
    echo "$(prefix) skip statusline.sh — not present"
  fi

  # claude-md: убрать управляемый блок из ~/.claude/CLAUDE.md (ручной контент сохраняем)
  local cmd_file="$CLAUDE_HOME/CLAUDE.md"
  if [ -f "$cmd_file" ] && grep -qF "my-claude-config (managed)" "$cmd_file"; then
    do_or_echo "sed -i.bak '/BEGIN my-claude-config (managed)/,/END my-claude-config (managed)/d' '$cmd_file'"
  else
    echo "$(prefix) claude-md — managed block not present"
  fi

  # Hooks: восстанавливаем из последнего бэкапа install-hooks.sh, если есть
  local settings="$CLAUDE_HOME/settings.json"
  local latest_bak
  latest_bak=$(ls -1t "$settings".bak.* 2>/dev/null | head -1 || true)
  if [ -n "$latest_bak" ]; then
    do_or_echo "cp '$latest_bak' '$settings'"
    echo "$(prefix) restored settings.json from $latest_bak"
  else
    echo "$(prefix) settings.json: no backup found, leaving as-is. Удали секцию 'hooks' вручную если нужно."
  fi

  # statusLine: убираем из settings.json (после restore хуков, чтобы он не вернул её обратно)
  if [ -f "$settings" ] && jq -e '.statusLine' "$settings" >/dev/null 2>&1; then
    do_or_echo "tmp=\$(mktemp) && jq 'del(.statusLine)' '$settings' > \"\$tmp\" && mv \"\$tmp\" '$settings'"
  else
    echo "$(prefix) settings.json: statusLine not present"
  fi

  echo
  if [ "$APPLY" -ne 1 ]; then
    echo "Это был dry-run. Чтобы реально применить:"
    echo "  $(basename "$0") uninstall --apply"
  fi
}

# ─── Dispatch ────────────────────────────────────────────────────────────────
case "$COMMAND" in
  status)    cmd_status ;;
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
esac
