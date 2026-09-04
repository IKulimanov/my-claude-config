# Claude Code Hooks — рабочий гайд

> Создано 2026-05-17 на основе доков Anthropic и анализа топ-репозиториев.
> Парный документ к `ROADMAP.md` (раздел «Hooks — переписать с нуля»).

## 1. Что говорит Anthropic (2026)

### Полный список событий — 29 в 7 категориях

| Категория | События | Когда срабатывают |
|---|---|---|
| Сессия | `SessionStart`, `SessionEnd`, `Setup`, `InstructionsLoaded` | начало/конец сессии, загрузка CLAUDE.md |
| Тёрн | `UserPromptSubmit`, `UserPromptExpansion`, `Stop`, `StopFailure` | пользователь жмёт enter / Claude закончил |
| Tool | `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`, `PermissionRequest`, `PermissionDenied` | до/после каждого вызова инструмента |
| Subagent | `SubagentStart`, `SubagentStop` | вызов Agent tool |
| Задачи | `TaskCreated`, `TaskCompleted`, `TeammateIdle` | TaskCreate/Update |
| Контекст | `PreCompact`, `PostCompact`, `CwdChanged`, `FileChanged`, `ConfigChange` | компакция, `cd`, изменения файлов |
| Worktree/MCP | `WorktreeCreate`, `WorktreeRemove`, `Elicitation`, `ElicitationResult`, `Notification` |  |

### Ключевые форматы

**Input в stdin (общий для всех событий):**
```json
{
  "session_id": "abc",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/working/dir",
  "permission_mode": "default|plan|acceptEdits|auto|bypassPermissions",
  "hook_event_name": "PreToolUse"
}
```
Плюс event-specific: `tool_name`, `tool_input`, `tool_use_id`, `prompt`, `response`, `error`, `source`, `agent_type`, и т.д.

**Output (по уровню важности):**

- **Exit code 0** → success. Для `SessionStart`/`UserPromptSubmit`/`Setup`/`SubagentStart` **stdout инжектится в контекст Claude**. Иначе — игнорируется.
- **Exit code 2** → **блокирующая ошибка**. stderr подаётся модели как сообщение об ошибке. Работает для `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `PreCompact`, `PermissionRequest`.
- **Любой другой ненулевой** → non-blocking, в transcript идёт только первая строка stderr.

**JSON response (предпочтительный для PreToolUse 2026):**
```json
{
  "continue": true,
  "stopReason": "...",
  "suppressOutput": false,
  "systemMessage": "shown to user",
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "...",
    "modifiedInput": { /* можно изменить tool_input */ },
    "additionalContext": "..."
  }
}
```

Важное:
- `PreToolUse` в 2026 использует `permissionDecision` (новое) вместо старого `decision: "approve"|"block"`. Старый формат ещё работает, но новый богаче — есть `ask` и `defer`.
- `UserPromptSubmit` отдаёт `additionalContext` для inject контекста + есть `sessionTitle` для авто-именования сессии.
- `Stop` через `decision: "block"` форсит продолжение работы.

### Matcher-синтаксис

| Что в matcher | Как интерпретируется |
|---|---|
| `"*"`, `""` или omit | matches everything |
| Только `[a-zA-Z0-9_\|]` | exact string или OR-список: `"Bash"`, `"Edit\|Write"` |
| Любой другой символ | **JavaScript regex**: `"^Notebook"`, `"mcp__memory__.*"` |

**Особый случай — `FileChanged`:** matcher тут не regex, а **только литералы**: `".env|.envrc"`.

**MCP tools:** формат `mcp__<server>__<tool>`. Чтобы поймать все из сервера — `mcp__memory__.*` (точка-звезда обязательны).

### Таймауты по умолчанию

- `command` / `http` / `mcp_tool` → **600 секунд**
- `UserPromptSubmit` → **30 секунд** (важно — короткий бюджет!)
- `prompt`-handlers → 30 секунд
- `agent`-handlers → 60 секунд

### Новые handler types (2026)

- **`command`** — привычный shell;
- **`http`** — POST на endpoint, ответ как JSON;
- **`mcp_tool`** — вызвать MCP инструмент как хук;
- **`prompt`** — мини-LLM-судья прямо в хуке (`"Is this command safe?"`);
- **`agent`** — полноценный subagent как хук.

### Что Anthropic настоятельно рекомендует

> «Hooks execute shell commands with your full user permissions. **You are responsible for ensuring your hooks are safe and secure.**»

1. **Always quote shell variables** (`"$VAR"`, `${VAR:-default}`).
2. **Block path traversal** — проверять `..` в `file_path`.
3. **Use absolute paths** через `$CLAUDE_PROJECT_DIR`.
4. **Skip sensitive files** — никогда не парсить `.env`, `.git/`, `id_rsa`.
5. **Validate input.** `jq -r '.tool_input.command // empty'` — пустая строка вместо null.
6. **Идемпотентность.** Хук должен переживать N повторных запусков без накопления.
7. **`disableAllHooks: true`** — kill-switch для отключения всего.
8. **Debug через `claude --debug`** — показывает stdout/stderr/exit code и сам JSON.

### Где хранить

- **`~/.claude/settings.json`** — глобальные (для всех проектов; осторожно).
- **`.claude/settings.json`** — проектные (чекать в Git).
- **`.claude/settings.local.json`** — личные оверрайды (gitignored).

---

## 2. Что используют топ-репозитории

### `disler/claude-code-hooks-mastery` — эталон

- 13 хуков с UV-скриптами (`#!/usr/bin/env -S uv run` + inline deps).
- Security validators с регексами под `rm -rf`, `git push --force`, `DROP TABLE`.
- Трёхуровневая TTS-иерархия (ElevenLabs → OpenAI → pyttsx3) с очередью `tts_queue.py` против перекрытия аудио.
- Anti-recursion через env-флаг `CLAUDE_HOOK_DEPTH`.

### `dhofheinz/claude-code-quality-hook`

Production quality pipeline: linter → auto-fix → claude-fix через git worktrees. Python/JS/TS/Go/Rust. `PostToolUse` с `exit 2` если линтер падает, Claude сразу видит ошибку и идёт чинить.

### `777genius/claude-notifications-go`

Кросс-платформенный плагин для нотификаций: Slack, Discord, Telegram, ntfy, Teams, PagerDuty, Zapier, n8n. С retry, circuit breaker, rate-limit.

### `syou6162/cchook`

YAML-обёртка над JSON-конфигом + декларативные `conditions` (например `file_extension: [.go, .java]`).

### `johnlindquist/claude-hooks`

TypeScript + Bun, типизированные payloads.

### Общие паттерны

1. **Структура каталога:**
   ```
   hooks/
     settings.json
     scripts/
       block-destructive.sh
       block-secrets.sh
       inject-jira.sh
       format-on-edit.sh
       notify-stop.sh
       lib/
         json.sh
         platform.sh
   ```
2. **Один скрипт на хук** — а не 5 скриптов в одной команде через `&&`.
3. **`set -euo pipefail`** в каждом скрипте.
4. **`jq` обязателен.** Все читают input через `INPUT=$(cat)`.
5. **Anti-recursion** через `CLAUDE_HOOK_DEPTH` env.
6. **Логирование** в `.claude/audit.jsonl` для отладки.

---

## 3. Готовый набор хуков под профиль Java/Go/Jira

### A. Безопасность

**1. Block destructive Bash** (`PreToolUse` / `Bash`)
```bash
#!/usr/bin/env bash
set -euo pipefail
INPUT=$(cat)
CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
if echo "$CMD" | grep -qE '(\brm\s+.*-[a-z]*r[a-z]*f|git\s+push.*--force.*\b(main|master|staging)\b|\bDROP\s+TABLE\b|\bchmod\s+777\b)'; then
  jq -n --arg r "Blocked: dangerous pattern. Run manually if intended." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
fi
exit 0
```

**2. Block secrets read/edit** (`PreToolUse` / `Read|Edit|Write|Bash`)
```bash
PATH_=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // empty')
if echo "$PATH_" | grep -qE '\.env(?!\.example|\.sample)|\.ssh/|aws/credentials|\.pem$|id_rsa|vault\.yml'; then
  echo "Secret access denied" >&2
  exit 2
fi
```

**3. Pre-push secret scan** (`PreToolUse` / `Bash` matching `git push`)
```bash
if [[ "$CMD" =~ ^git[[:space:]]+push ]]; then
  if command -v trufflehog >/dev/null; then
    trufflehog filesystem --no-update . 2>/dev/null | tee /tmp/scan
    [[ -s /tmp/scan ]] && { echo "Secrets detected — push blocked"; exit 2; }
  fi
fi
```

### B. Качество кода

**4. Auto-format универсальный диспетчер** (`PostToolUse` / `Edit|Write|MultiEdit`)
```bash
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
[ -z "$FILE" ] && exit 0
case "$FILE" in
  *.go)   gofmt -w "$FILE" ;;
  *.java) mvn -q formatter:format -Dformatter.includes="$FILE" 2>/dev/null || true ;;
  *.ts|*.tsx|*.js|*.jsx|*.json|*.vue|*.md) npx --no-install prettier --write "$FILE" 2>/dev/null || true ;;
  *.py) command -v ruff && ruff format "$FILE" ;;
esac
```
**Критично:** `--no-install` иначе агент будет ждать `npm install` в середине сессии.

**5. Lint after edit с блоком** (`PostToolUse` / `Edit|Write`)
```bash
case "$FILE" in
  *.go) go vet "$(dirname "$FILE")/..." 2>&1 | head -20 >&2 && exit 2 ;;
esac
```
`exit 2` — фича: Claude видит stderr и сразу пойдёт чинить.

### C. Jira / workflow

**6. Inject Jira ID и контекст ветки** (`UserPromptSubmit`)
```bash
#!/usr/bin/env bash
cd "$CLAUDE_PROJECT_DIR" 2>/dev/null || exit 0
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
JIRA=$(echo "$BRANCH" | grep -oE '[A-Z]+-[0-9]+' || true)
LAST=$(git log -5 --oneline 2>/dev/null || echo "")
CTX="Branch: $BRANCH"
[ -n "$JIRA" ] && CTX="$CTX | Active Jira: $JIRA"
CTX="$CTX

Recent commits:
$LAST"
jq -n --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"UserPromptSubmit",additionalContext:$c}}'
```

**7. SessionStart — открытые PR + sprint** (с кэшем!)
```bash
#!/usr/bin/env bash
CACHE=/tmp/claude-session-ctx
if [ -f "$CACHE" ] && [ $(($(date +%s) - $(stat -f %m "$CACHE" 2>/dev/null || stat -c %Y "$CACHE"))) -lt 600 ]; then
  cat "$CACHE"; exit 0
fi
PRS=$(gh pr list --assignee @me --limit 5 2>/dev/null || echo "(gh unavailable)")
CTX="Open PRs:\n$PRS"
jq -n --arg c "$CTX" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}' | tee "$CACHE"
```
**Помни:** `UserPromptSubmit` имеет лимит **30 секунд**, без кэша Jira API легко срежет промпт.

### D. Уведомления (Stop)

**8. macOS native notification** (`Stop`)
```bash
osascript -e 'display notification "Claude finished" with title "Claude Code" sound name "Glass"'
```

**9. Telegram bot** (`Stop`)
```bash
TOK="$TELEGRAM_BOT_TOKEN"; CHAT="$TELEGRAM_CHAT_ID"
SUMMARY=$(echo "$INPUT" | jq -r '.response // "done"' | head -c 200)
curl -s "https://api.telegram.org/bot$TOK/sendMessage" \
  -d "chat_id=$CHAT" -d "text=Claude: $SUMMARY" >/dev/null
```

**10. TTS на macOS** (`Stop`)
```bash
say -v Milena "Готово"
```

### E. Life-ops / привычки

**11. Журнал работы в Obsidian** (`Stop`)
```bash
DATE=$(date +%Y-%m-%d); TIME=$(date +%H:%M)
RESP=$(echo "$INPUT" | jq -r '.response // ""' | head -c 400)
CWD=$(echo "$INPUT" | jq -r '.cwd')
mkdir -p "$HOME/Obsidian/work-log"
{
  echo "### $TIME — $(basename "$CWD")"
  echo "$RESP"
  echo
} >> "$HOME/Obsidian/work-log/$DATE.md"
```

**12. Pomodoro — напоминание каждые 25 минут** (`Stop` с throttling)
```bash
STAMP=/tmp/claude-pomodoro
NOW=$(date +%s)
LAST=$(cat "$STAMP" 2>/dev/null || echo 0)
if [ $((NOW - LAST)) -gt 1500 ]; then
  osascript -e 'display notification "Перерыв 5 минут" with title "Pomodoro"'
  echo "$NOW" > "$STAMP"
fi
```

**13. Auto-WIP stash раз в час** (`Stop`)
```bash
LAST=/tmp/claude-wip-stash
NOW=$(date +%s)
if [ $((NOW - $(cat "$LAST" 2>/dev/null || echo 0))) -gt 3600 ]; then
  cd "$CLAUDE_PROJECT_DIR" 2>/dev/null
  if [ -n "$(git diff --shortstat 2>/dev/null)" ]; then
    git stash push -m "claude-wip-$(date +%s)" --include-untracked 2>/dev/null
  fi
  echo "$NOW" > "$LAST"
fi
```
**Важно:** не делать через `git commit` — засрёт историю. Stash безопаснее.

**14. Звуковой сигнал когда долго ждёт ответа** (`Notification` matcher `idle_prompt`)
```bash
afplay /System/Library/Sounds/Glass.aiff
```

### F. Телеметрия

**15. Audit log всех tool calls** (`PreToolUse` + `PostToolUse` с `matcher: "*"`)
```bash
echo "$INPUT" | jq -c '{ts:now, event:.hook_event_name, tool:.tool_name, session:.session_id}' \
  >> "$CLAUDE_PROJECT_DIR/.claude/audit.jsonl"
```

**16. Подсчёт затрат за день** (`Stop`)
```bash
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path')
TODAY=$(date +%Y-%m-%d)
TOKENS=$(jq -r 'select(.usage) | .usage.input_tokens + .usage.output_tokens' "$TRANSCRIPT" | awk '{s+=$1} END {print s}')
echo "{\"date\":\"$TODAY\",\"tokens\":$TOKENS}" >> "$HOME/.claude/daily-usage.jsonl"
```

### G. Команда / коллаборация

**17. PR-комменты в SessionStart** (с кэшем)
```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD)
PR=$(gh pr view "$BRANCH" --json number -q .number 2>/dev/null || true)
if [ -n "$PR" ]; then
  CMNTS=$(gh pr view "$PR" --json comments -q '.comments[] | .body' 2>/dev/null | head -c 2000)
  jq -n --arg c "Open PR #$PR comments:\n$CMNTS" \
    '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$c}}'
fi
```

---

## 4. Антипаттерны

1. **Бесконечный Stop-цикл.** Stop-хук с `exit 2` форсит продолжение. Если хук всегда падает — петля. Защита:
   ```bash
   [ "$(echo "$INPUT" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0
   ```
2. **Hot-loop format + lint.** Prettier и ESLint правят одно и то же → бесконечные правки. Используй `eslint --fix` один раз, либо `eslint-config-prettier`.
3. **Heavy PreToolUse.** `mvn verify` на каждый Bash — катастрофа. Делай guard: `[[ "$CMD" =~ ^git\ push ]] || exit 0`.
4. **Рекурсия через `claude` CLI.** Если хук вызывает `claude` или `claude -p "..."`, новый процесс запустит те же хуки:
   ```bash
   [ -n "${CLAUDE_HOOK_DEPTH:-}" ] && exit 0
   export CLAUDE_HOOK_DEPTH=1
   ```
5. **`sudo` в хуке = root-эскалация.** Любой prompt-injection через `tool_input.command` исполнит код с root. Никогда не пиши `sudo` в хук-скриптах.
6. **`source .env` в хуке.** Значения утекают в env subprocess'а → могут попасть в логи. Читай только нужные переменные: `grep -E '^JIRA_TOKEN=' .env | cut -d= -f2`.
7. **Долгий `UserPromptSubmit`.** Лимит 30 сек, не 600. Без кэша Jira/Slack/GitHub fetch обрежет промпт.
8. **`exit 1` НЕ блокирует.** Только `exit 2` или JSON с `permissionDecision: deny` / `decision: block`.
9. **Глобальные хуки в `~/.claude/settings.json`** работают для всех проектов. Не клади туда Java-specific логику.

---

## 5. Кросс-платформенность

| Зависимость | macOS | Linux | Windows |
|---|---|---|---|
| `jq` | brew install jq | apt install jq | scoop install jq |
| `say` | встроено | `espeak` | PowerShell SAPI |
| `osascript` | встроено | — | — |
| `notify-send` | — | libnotify | — |
| `afplay` | встроено | `aplay`/`paplay` | — |

Универсальный wrapper:
```bash
notify() {
  local title="$1" msg="$2"
  case "$(uname -s)" in
    Darwin) osascript -e "display notification \"$msg\" with title \"$title\"" ;;
    Linux)  command -v notify-send && notify-send "$title" "$msg" ;;
  esac
}
```

Альтернатива — UV single-file scripts (как у `disler`):
```python
#!/usr/bin/env -S uv run --quiet
# /// script
# dependencies = ["pydantic"]
# ///
```
Zero-install, кроссплатформенно, ценой uv-runtime.

---

## 6. Стартовый минимум (7 хуков)

| # | Событие | Назначение |
|---|---|---|
| 1 | `PreToolUse` / `Bash` | Block `rm -rf`, force-push в main/staging, DROP TABLE |
| 2 | `PreToolUse` / `Read\|Edit\|Write` | Block `.env`, `~/.ssh`, vault.yml |
| 3 | `PostToolUse` / `Edit\|Write` | Format dispatcher (gofmt/prettier/mvn formatter) |
| 4 | `UserPromptSubmit` | Inject Jira ID + branch + last 5 commits |
| 5 | `SessionStart` | Open PRs (gh, с 10-min кэшем) |
| 6 | `Stop` | macOS notification + лог в Obsidian |
| 7 | `PostToolUse` / `*` | Audit log в `.claude/audit.jsonl` |

Это ~70% всей пользы хуков при минимуме сложности.

---

## 7. Реализация в этом репозитории

Готовые скрипты лежат в `hooks/scripts/`. Покрыты:

**Блокирующие:**
- `block-destructive.sh` — PreToolUse / Bash. Блок `rm -rf`, `git push --force` в main/master/staging/prod, `DROP TABLE`, `TRUNCATE`, `chmod 777`, `mkfs.*`.
- `block-secrets.sh` — PreToolUse / Read|Edit|Write|Bash. Два режима. Для Read/Edit/Write проверяется
  `file_path` — это точный путь, ложных срабатываний нет. Для Bash проверяются **только аргументы
  читающих команд** (`cat`, `cp`, `scp`, `base64`, `source` и т.п.), а не вся строка команды.
  Раньше был поиск подстроки по всей команде: он блокировал `grep .env docs/` и даже комментарий со
  словом `.envrc` — три ложные блокировки за первые минуты работы 2026-09-04. Регрессия:
  `tests/test-block-secrets.sh`. Дублирующая защита — `permissions.deny` в `settings.json`.
- `block-push-secrets.sh` — PreToolUse / Bash. Перед `git push` запускает `trufflehog` по **коммитам,
  которых ещё нет на сервере** (полный скан ругался на примеры из документации, лежащие в истории).
  Апстрима нет — сканируется весь каталог. Ложные срабатывания снимаются файлом `.trufflehogignore`
  в корне репозитория. В сообщении блокировки указано место находки. Если `trufflehog` не установлен,
  в `blocks.jsonl` пишется запись `kind: "scan-skipped"` — чтобы отсутствие защиты было видно в аудите,
  а не выглядело как чистый результат. Регрессия: `tests/test-block-push-secrets.sh`.

**Уведомления:**
- `notify-stop.sh` — Stop. macOS `osascript display notification` с звуком Glass; Linux `notify-send`. Защита от Stop-петли через `stop_hook_active`.

**Логирование (для аналитики):**
- `log-tool.sh` — PreToolUse/PostToolUse/PostToolUseFailure. Пишет в `~/.claude/logs/tools.jsonl` каждый tool call (инструмент, агент, краткий input, размер результата).
- `log-session.sh` — SessionStart/SessionEnd → `sessions.jsonl`.
- `log-subagent.sh` — SubagentStart/SubagentStop → `subagents.jsonl`. **Главный источник «какие агенты я использую».**
- `log-prompt.sh` — UserPromptSubmit → `prompts.jsonl`. Метаданные промпта (длина, slash-команда, первые 500 символов в `head`).
- `log-instructions.sh` — InstructionsLoaded → `instructions.jsonl`. Только загрузки CLAUDE.md/rules/памяти — **skills сюда НЕ попадают**. Источник «какие skills реально подхватились» — Skill-вызовы в `tools.jsonl` (`tool=="Skill"`, имя в `input.skill`), см. `analyze-usage.sh`.
- `log-stop.sh` — Stop → `stops.jsonl`. Парсит transcript, считает input/output/cache токены, перечисляет использованные модели. ВАЖНО: Stop срабатывает после каждого ответа и каждый раз пересуммирует ВЕСЬ транскрипт — строки кумулятивны в рамках сессии. Сумма сессии = последняя строка (или дельта за период), а не сумма строк.

**Общая библиотека:** `hooks/scripts/lib/common.sh` — `hook_log`, `hook_field`, `hook_deny`, `hook_now`, `hook_project_name`.

## 8. Установка

Хуки сейчас сделаны **глобальными** через `~/.claude/settings.json` — работают для всех проектов, логи попадают в `~/.claude/logs/`. Это даёт единую аналитику использования.

**Способ 1 — автоматически (с бэкапом):**
```bash
./scripts/install-hooks.sh --write
```
Сохранит существующий `~/.claude/settings.json` в `*.bak.<timestamp>`. Из `hooks/settings.json`
ставятся три вещи: `hooks` и `cleanupPeriodDays` перезаписываются нашими значениями, `permissions`
(allow и deny) **объединяются** с уже существующими — свои разрешения пользователя не теряются.
Остальные ключи файла не трогаются. Регрессия: `tests/test-settings-merge.sh`.

Логирующие хуки (`log-*`, `notify-stop`) помечены `"async": true` — они не задерживают вызов
инструмента. Блокирующие (`block-*`) остаются синхронными, иначе они не смогут запретить действие.
Замер до перевода в async: логирующий хук 51 мс, два таких на каждый вызов инструмента.
Журналы ротируются при 20 МБ (`CLAUDE_LOG_MAX_MB`), старые срезы остаются для месячного аудита.

**Способ 2 — посмотреть что встанет:**
```bash
./scripts/install-hooks.sh
```
Печатает отрендеренный JSON (с абсолютными путями), руками копируешь в `~/.claude/settings.json`.

**Проверка:**
```bash
claude --debug         # увидишь как срабатывают хуки
ls ~/.claude/logs/     # после нескольких сессий — файлы с данными
```

**Анализ использования:**
```bash
./scripts/analyze-usage.sh         # вся история
./scripts/analyze-usage.sh 7       # последние 7 дней
./scripts/analyze-usage.sh 7 my-app # последние 7 дней, только проект "my-app"
```
Печатает: топ инструментов, топ subagent'ов, топ skills, slash-команды, токены, топ проектов по токенам, заблокированные действия.

## 9. Что не делает текущая реализация

- Нет `inject-jira.sh` (UserPromptSubmit) — будет в следующей итерации.
- Нет `format-on-edit.sh` (PostToolUse / Edit) — нужен решительный выбор стека (project-level через `.claude/settings.json`, чтобы не ломать кросс-стек проекты).
- Нет TTS (`say`/ElevenLabs) — пока только тихая нотификация macOS.
- Нет per-project установки — хуки глобальные (ставит `setup-global.sh` / `install-hooks.sh`).

---

## 10. Источники

**Anthropic (читать обязательно):**
- [Hooks reference](https://code.claude.com/docs/en/hooks) — все 29 событий
- [Hooks guide](https://code.claude.com/docs/en/hooks-guide) — туториал и safety
- [Anthropic blog: how to configure hooks](https://claude.com/blog/how-to-configure-hooks)
- [Agent SDK hooks](https://platform.claude.com/docs/en/agent-sdk/hooks)

**Эталонные репозитории:**
- [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) — самый полный референс, 13 хуков, TTS pipeline
- [dhofheinz/claude-code-quality-hook](https://github.com/dhofheinz/claude-code-quality-hook) — linter→fix→claude-fix через worktrees
- [777genius/claude-notifications-go](https://github.com/777genius/claude-notifications-go) — кросс-платформенные нотификации
- [syou6162/cchook](https://github.com/syou6162/cchook) — YAML-обёртка с conditions
- [johnlindquist/claude-hooks](https://github.com/johnlindquist/claude-hooks) — TypeScript + Bun

**Туториалы:**
- [thomas-wiegold.com — security gate + Stop verification](https://thomas-wiegold.com/blog/claude-code-hooks/)
- [blakecrosley.com — 5 production хуков](https://blakecrosley.com/blog/claude-code-hooks-tutorial)
- [pixelmojo.io — defense-in-depth tier](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns)
- [khromov.se — macOS notifications](https://khromov.se/claude-code-hooks-for-simple-macos-notifications/)
- [claudelog.com/mechanics/hooks/](https://claudelog.com/mechanics/hooks/) — edge cases

---

**TL;DR.** Anthropic довела API до 29 событий с richer JSON-выходом (`permissionDecision` вместо `decision`, `additionalContext` для inject). Топ-репозитории сходятся на формате: `hooks/scripts/*.sh`, `set -euo pipefail`, `jq` обязателен, anti-recursion через env-флаг, кэш для тяжёлых вызовов. Под профиль Java/Go/Jira самые ценные — security (rm -rf / secrets), `UserPromptSubmit` с Jira ID, format-on-edit, и Stop-нотификация в macOS. Стартовых 7 хуков покрывают 70% возможной пользы.
