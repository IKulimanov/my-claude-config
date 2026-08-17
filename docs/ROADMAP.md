# Roadmap: улучшение Claude Code конфига

> Создано 2026-05-16 на основе ревью и исследования топ-репозиториев.
> Это рабочий чек-лист. Отмечай галочками по мере выполнения.
>
> Каталог идей из публичных репо (RESEARCH_FINDINGS) удалён 2026-08-16: см. `docs/audit-2026-08/` — конфиг меняется по данным, не по каталогу идей.

## Контекст

После ревью выяснилось, что архитектура слоёв (`rules / commands / agents / skills / hooks / templates`) — в верхнем квартиле, но есть отставание по деталям инструмента и тренды 2026 года не учтены. Quick Wins уже сделаны — дальше идёт более крупная работа.

---

## ✅ Уже сделано (Quick Wins, 2026-05-16)

- [x] `rules/01..05` переписаны: убраны дубли системного промпта Claude Code; оставлены только специфичные правила (Jira ID, staging-flow, Vault, командная конвенция).
- [x] Агенты: убрано несуществующее поле `maxTurns`. ВАЖНО: поле `skills:` ОФИЦИАЛЬНО
  поддерживается и возвращено 2026-06-19 (канон: `name`, `description`, `tools`, `model`, `skills`
  — см. CLAUDE.md «Конвенции авторинга»). Старая формулировка «skills: не существует» — ошибка.
- [x] Все 14 команд: добавлены `argument-hint` и `allowed-tools`. Убраны изобретённые `effort:`, `context: fork`.
- [x] `templates/settings.*.json.template`: убраны `Bash(sed *)` (обходит Edit/Write) и `Bash(cat *)` (запрещён системным промптом).
- [x] Разведены `web-app` ↔ `vue-frontend`: в SKILL.md и web-reviewer явно прописано «NOT for Vue/React/SPA».
- [x] Обновлена память проекта (`memory/project_config_state.md`).

## ✅ Аналитика v1 — недельный пайплайн (2026-07-11)

- [x] `scripts/collect-weekly.sh` — недельные снапшоты (Сб–Пт UTC) в `analytics/history/`,
  бэкфилл с 2026-W21; общая jq-логика в `scripts/lib/usage-lib.sh`.
- [x] `scripts/render-dashboard.sh` + `templates/dashboard.html.template` — автономный дашборд.
- [x] `analytics/weekly-review-prompt.md` — промт недельного анализа (5 ролей, анти-галлюцинация).
- [x] `scripts/run-weekly-review.sh` — оркестратор: сбор → headless `claude -p` → дашборд → коммит.
- [x] `scripts/install-weekly-analytics.sh` — launchd-джоб (Сб 09:00 + страховка Вс/Пн).
- [x] Фикс: `blocks.jsonl` теперь пишет `project`; токены в `analyze-usage.sh` считаются
  дельтами кумулятивных стопов (раньше завышались на порядки).
- [ ] Ротация `tools.jsonl` (28+ MiB и растёт) — по мере надобности.

## ✅ Hooks v1 — реализованы (2026-05-17)

- [x] Библиотека `hooks/scripts/lib/common.sh` (общие helpers).
- [x] **Безопасность:** `block-destructive.sh`, `block-secrets.sh`, `block-push-secrets.sh` (с trufflehog).
- [x] **Уведомления:** `notify-stop.sh` (macOS + Linux, защита от Stop-петли).
- [x] **Логирование:** 6 скриптов пишут в `~/.claude/logs/*.jsonl`: tools, sessions, subagents, prompts, instructions, stops (с подсчётом токенов из transcript).
- [x] `hooks/settings.json` переписан с правильным matcher-синтаксисом 2026.
- [x] `scripts/install-hooks.sh` — установка глобально с бэкапом.
- [x] `scripts/analyze-usage.sh` — отчёт по использованию (топ tools/agents/skills/токенов).
- [x] Все 13 скриптов протестированы вручную.

**Что осталось из hooks-плана:** inject-jira.sh (UserPromptSubmit), format-on-edit.sh (PostToolUse / Edit), TTS-нотификация. Подробности — `docs/HOOKS_GUIDE.md` раздел 9.

## ✅ Context7 MCP — установлен (2026-05-17)

- [x] Установлен через `claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp`.
- [x] Проверен: `claude mcp list` → `context7: ✓ Connected`.
- [x] Доступен глобально для всех проектов через `~/.claude.json`.

Использование: спрашивай у Claude вещи типа «дай актуальную доку Spring Boot 3.4 по `@ConfigurationProperties`» — он сам подтянет up-to-date через Context7 вместо устаревшего знания.

## ✅ TDD + canonical convention + /onboard (2026-05-17)

Три требования к каждой фиче/правке/проектированию теперь зашиты в конфиг:

- [x] **`rules/06-tdd-discipline.md`** — iron law TDD (RED → GREEN → REFACTOR), always-on. Запрещает «уже руками потестил», «потом тест добавлю».
- [x] **`skills/java-service-convention/SKILL.md`** переписан — для проектов под `~/dev/work/` авторитетный источник `/Users/ivankulimanov/dev/work/java/convention-java/docs/` (а не reworked-summary в skill'е). Для личных проектов — guardrails как best-practices.
- [x] **`commands/feature.md`** — Step 6 теперь TDD-first iron law. Step 1 детектит work-project и заставляет грузить канон.
- [x] **`commands/fix.md`** — workflow переписан как TDD: тест воспроизводит баг → фикс → проверка.
- [x] **`commands/arch.md`** — Step 1 детектит work-project и направляет дизайн под канон.
- [x] **`commands/onboard.md`** — новая команда. Детектит стек (java/go/vue/web/docker), детектит work-vs-personal по cwd, берёт шаблон из `templates/`, задаёт точечные вопросы через `AskUserQuestion`, заполняет `CLAUDE.md`.

**Как использовать:**
- В новом репо: `/onboard` → ответы на 5-6 вопросов → готовый CLAUDE.md.
- Любая фича/правка: `/feature` или `/fix` — TDD обязательно, канон подгружается автоматически если ты в `~/dev/work/`.

## 🛠 setup-global.sh — готов, не применён (2026-05-17)

`scripts/setup-global.sh` разворачивает весь конфиг в `~/.claude/` одной командой — для нового устройства или для перехода на global-first архитектуру.

- [x] Поддерживает `status`, `install`, `uninstall`. Dry-run по умолчанию.
- [x] Бэкапит существующие файлы в `~/.claude/backups/global-install-<ts>/`.
- [x] Идемпотентен, безопасный uninstall (трогает только наши symlinks).
- [x] Прогон `status` показал что в `~/.claude/` сейчас skills/agents/commands отсутствуют — машина чистая.

**Не применять пока:** структура ещё дорабатывается (vue/web дубли, MCP, новые skills, `/onboard` команда). Когда финализируешь — запустить `./scripts/setup-global.sh install --apply` на текущей машине и удалить `.claude/skills,agents,commands,rules` из существующих проектов.

**На новом устройстве:**
```bash
git clone <repo> ~/dev/my-claude-config
cd ~/dev/my-claude-config
./scripts/setup-global.sh install --apply
```

Полный план миграции и verify-чеклист — `~/.claude/plans/starry-foraging-pnueli.md`.

---

## 🔥 High ROI (делать первым)

### 1. ~~Hooks — переписать с нуля~~ (сделано 2026-05-17)

> 📖 См. **[`docs/HOOKS_GUIDE.md`](HOOKS_GUIDE.md)** разделы 7–9 — что готово, как установить, что осталось.

Готово v1: блокировка destructive/secrets, macOS нотификация, полное логирование сессий/инструментов/агентов/skills/токенов с анализатором `scripts/analyze-usage.sh`.

**Зачем было нужно:** старый `hooks/settings.json` использовал matcher вида `tool == "Bash" && tool_input.command matches "..."` — Claude Code так не парсит, хуки были пустышкой.

**Как правильно:**
- `matcher` = имя инструмента (regex), например `"Bash"`, `"Edit|Write|MultiEdit"`, `"*"`.
- Логика фильтрации внутри shell-скрипта, который читает JSON из stdin.
- `exit 0` — продолжить, `exit 2` — заблокировать (текст stderr увидит Claude), любой другой код — warning.

**План (выполнен 2026-05-17, кроме inject-jira/lint-on-edit — см. HOOKS_GUIDE §9):**

- [x] Создать `hooks/scripts/` с исполняемыми скриптами.
- [x] Переписать `hooks/settings.json` под правильный синтаксис matcher (см. шаблон ниже).
- [x] Добавить `block-destructive.sh` (PreToolUse / Bash).
- [x] Добавить `block-secrets.sh` (PreToolUse / Edit|Write — блок `.env`, `id_rsa`, `*.pem`).
- [ ] Добавить `inject-jira.sh` (UserPromptSubmit — извлечь Jira ID из ветки и инжектить контекст).
- [ ] Опционально: `lint-on-edit.sh` (PostToolUse — `mvn compile` для Java, `go vet` для Go).
- [x] Опционально: `notify-stop.sh` (Stop — звуковое/desktop уведомление о завершении).
- [x] Проверить вручную: попытаться сделать `git push -f` — должно блокироваться.

**Шаблон `hooks/settings.json`:**
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/scripts/block-destructive.sh" }]
      },
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/scripts/block-secrets.sh" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/scripts/lint-on-edit.sh" }]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [{ "type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/scripts/inject-jira.sh" }]
      }
    ]
  }
}
```

**Шаблон `block-destructive.sh`:**
```bash
#!/usr/bin/env bash
set -euo pipefail
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
if echo "$cmd" | grep -Eq '(^|[^a-z])(rm -rf /|git push.*--force|git push.*-f( |$)|reset --hard|DROP TABLE|drop table)'; then
  echo "[Hook] Blocked: destructive command requires manual run." >&2
  exit 2
fi
exit 0
```

**Шаблон `inject-jira.sh`:**
```bash
#!/usr/bin/env bash
issue=$(git branch --show-current 2>/dev/null | grep -oE '[A-Z]+-[0-9]+' || true)
if [ -n "$issue" ]; then
  printf '<system>Active Jira issue: %s</system>' "$issue"
fi
```

**Документация:**
- https://docs.claude.com/en/docs/claude-code/hooks
- https://docs.claude.com/en/docs/claude-code/hooks-guide

---

### 2. MCP-серверы (самая высокая ROI для рабочего профиля)

**Зачем:** работаешь с Jira ежедневно, без MCP это раз в час копировать-вставлять описания тикетов. С MCP — Claude сам читает и обновляет.

| Сервер | Зачем | Ссылка |
|---|---|---|
| **Atlassian Remote MCP** (официальный) | Jira + Confluence | https://www.atlassian.com/platform/remote-mcp-server |
| **GitHub MCP** (официальный) | PR/issues без `gh` | https://github.com/github/github-mcp-server |
| **Context7** | Актуальная документация Spring/Hibernate/Go в контексте | https://github.com/upstash/context7 |
| **Postgres MCP** | Read-only запросы к dev/staging БД | https://github.com/modelcontextprotocol/servers/tree/main/src/postgres |
| **Sentry MCP** | Чтение ошибок и стектрейсов | https://github.com/getsentry/sentry-mcp |
| **Filesystem MCP** | Read-only sandbox для шаринга папок | https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem |

**План:**

- [ ] Прочитать https://docs.claude.com/en/docs/claude-code/mcp и https://modelcontextprotocol.io.
- [ ] Подключить **Atlassian Jira MCP** (приоритет №1).
- [ ] Подключить **Context7**.
- [ ] Проверить на реальной задаче: попросить «возьми задачу `ABC-123`, спланируй».
- [ ] Опционально: GitHub MCP, Postgres MCP, Sentry MCP.
- [ ] Обновить шаблоны `CLAUDE.*.md.template` — добавить блок «доступные MCP».

---

### 3. Statusline

**Зачем:** видеть в реальном времени токены, rate-limit, ветку, worktree. Это меняет привычки.

**Варианты:**
- **`ccstatusline`** — https://github.com/sirmalloc/ccstatusline (фокус на 5h/7d лимитах)
- **`claude-powerline`** — https://github.com/Owloops/claude-powerline (powerline-стиль)

**Выполнено иначе (2026-06): собственный `statusline/statusline.sh`, ставится
`setup-global.sh` (компонент `statusline`). Сторонние ccstatusline/claude-powerline не нужны.**

---

## 🟡 Средний приоритет

### 4. Сократить README

**Текущая проблема:** 618 строк, дублирует содержимое `docs/`, рассинхронизируется с реальностью.

- [ ] Оставить в `README.md` ≤100 строк: что это, зачем, быстрый старт, ссылки на `docs/`.
- [ ] Перенести подробности в `docs/USAGE_GUIDE.md` и `docs/EXTENSION_GUIDE.md`.
- [x] Удалить устаревшие docs: REPO_COMPARISON, GITHUB_PUBLISHING, CONVENTION_INTEGRATION, TEAM_ONBOARDING, CONFIG_PHILOSOPHY, STACK_PROFILES.


### 5. Meta-skill: skill-creator

**Зачем:** добавление новых skill сейчас — копи-паст по образцу, легко забыть progressive disclosure паттерн. Meta-skill закрывает это.

- [ ] Прочитать https://github.com/anthropics/skills/tree/main/skill-creator
- [ ] Скопировать паттерн себе как `skills/skill-creator/SKILL.md` (адаптировать под свой репо).
- [ ] Использовать его для создания одного нового skill — например `oracle-migrations` или `clickhouse-analytics`.

### 6. Output Style для backend-review

**Зачем:** в ревью часто забываешь Risks/Rollback. Output style принуждает.

- [ ] Создать `~/.claude/output-styles/backend-review.md`:
  ```markdown
  ---
  name: backend-review
  description: Backend review style — always include Risks, Rollback, Validation
  ---

  Every response that proposes a code change MUST include:
  ## Risks
  - ...
  ## Rollback
  - ...
  ## Validation
  - ...
  ```
- [ ] Активировать через `/output-style backend-review` на ревью-сессии.
- [ ] Документация: https://docs.claude.com/en/docs/claude-code/output-styles

### 7. Worktree isolation для агентов, пишущих код

**Зачем:** параллельные запуски не конфликтуют, рефакторы безопаснее.

- [ ] Прочитать https://docs.claude.com/en/docs/claude-code/worktrees
- [ ] Включить `isolation: worktree` для `test-writer`, `go-test-writer`, `vue-test-writer` (они пишут код).
- [ ] Reviewer-агенты НЕ нужно — они только читают.

---

## 🟢 Стратегические (когда фундамент готов)

### 8. Packaging как plugin

**Зачем:** установка на новой машине = `/plugin install`, а не `setup-global.sh`. Версионирование через git tags.

- [ ] Прочитать https://docs.claude.com/en/docs/claude-code/plugins и https://docs.claude.com/en/docs/claude-code/plugin-marketplaces
- [ ] Создать `.claude-plugin/plugin.json`:
  ```json
  {
    "name": "ivan-claude-config",
    "version": "1.0.0",
    "description": "Personal Claude Code config: Java/Spring + Go + Vue + DevOps",
    "components": ["skills", "agents", "commands", "hooks"]
  }
  ```
- [ ] Тегнуть `v1.0.0`.
- [ ] Установить на резервной машине: `/plugin install github:kulimanov/my-claude-config`.

### 9. TDD-enforcer subagent (для Go side-projects)

**Зачем:** методология из [`obra/superpowers`](https://github.com/obra/superpowers) — код не существует без проходящего теста. Дисциплина для пет-проектов.

- [ ] Прочитать superpowers/tdd-enforcer.
- [ ] Создать `agents/go-tdd-enforcer.md` для Go side-projects.

### 10. Новые доменные skills

Закрыть пробелы по реальному стеку.

- [ ] `oracle-migrations` — DDL, locks, online ops, vendor-specific.
- [ ] `clickhouse-analytics` — engine choice, partitioning, materialized views.
- [ ] `spring-api-contracts` — OpenAPI, *Api интерфейсы для Swagger, версионирование.
- [ ] `observability` — OpenTelemetry, Prometheus, Grafana, structured logging.

---

## 📚 Что изучить (источники)

### Обязательно прочесть (Anthropic docs)

1. https://docs.claude.com/en/docs/claude-code/overview — все возможности 2026
2. https://docs.claude.com/en/docs/claude-code/skills — каноничный паттерн skill
3. https://docs.claude.com/en/docs/claude-code/sub-agents — реальные поля frontmatter
4. https://docs.claude.com/en/docs/claude-code/hooks + .../hooks-guide
5. https://docs.claude.com/en/docs/claude-code/slash-commands — `argument-hint`, `allowed-tools`, `$ARGUMENTS`, `!bash`, `@file`
6. https://docs.claude.com/en/docs/claude-code/plugins + .../plugin-marketplaces
7. https://docs.claude.com/en/docs/claude-code/worktrees
8. https://docs.claude.com/en/docs/claude-code/statusline + .../output-styles
9. https://docs.claude.com/en/docs/claude-code/memory + .../settings
10. https://docs.claude.com/en/docs/claude-code/mcp + https://modelcontextprotocol.io

### Anthropic engineering blog

1. https://www.anthropic.com/engineering/building-effective-agents — фундамент агентов
2. https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
3. https://www.anthropic.com/engineering/claude-code-best-practices
4. https://www.anthropic.com/engineering/equipping-agents-with-skills

### Видео и курсы

- **Anthropic YouTube** — https://www.youtube.com/@anthropic-ai (серии Claude Code и Skills)
- **DeepLearning.AI**: бесплатный курс «Claude Code: A Highly Agentic Coding Assistant» — https://www.deeplearning.ai/short-courses/claude-code-a-highly-agentic-coding-assistant/
- **Anthropic Academy** — https://anthropic.skilljar.com

### Образцовые репозитории

1. **[anthropics/skills](https://github.com/anthropics/skills)** ~37k ⭐ — канон skill-структуры
2. **[obra/superpowers](https://github.com/obra/superpowers)** ~94k ⭐ — 7-фазная методология (Brainstorm → Spec → Plan → TDD → Subagent → Review → Finalize)
3. **[hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)** ~21k ⭐ — каталог
4. **[wshobson/agents](https://github.com/wshobson/agents)** — multi-agent orchestration
5. **[0xfurai/claude-code-subagents](https://github.com/0xfurai/claude-code-subagents)** — 100+ subagents
6. **[rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit)** — большой harness
7. **[travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)** — каталог skills
8. **[anthropics/claude-code](https://github.com/anthropics/claude-code)** — issues для мониторинга планов и багов

---

## 👁 За кем следить

### GitHub-аккаунты

| Кто | Зачем |
|---|---|
| [@anthropics](https://github.com/anthropics) | Skills, Agent SDK, claude-code, MCP servers |
| [@obra](https://github.com/obra) (ex-Anthropic) | Superpowers, методология TDD-enforced |
| [@hesreallyhim](https://github.com/hesreallyhim) | Awesome-claude-code куратор |
| [@modelcontextprotocol](https://github.com/modelcontextprotocol) | Эталонные MCP-серверы |
| [@upstash](https://github.com/upstash) | Context7 |
| [@wshobson](https://github.com/wshobson) | Multi-agent патерны |

### RSS / каналы

- **Anthropic blog** — https://www.anthropic.com/news (RSS: https://www.anthropic.com/rss.xml)
- **Anthropic engineering** — https://www.anthropic.com/engineering
- **Claude Code changelog** — https://docs.claude.com/en/docs/claude-code/changelog
- **Anthropic Discord** — https://discord.gg/anthropic, канал `#claude-code`

---

## 🗓 Предлагаемый темп

### Неделя 1 — фундамент
- **День 1.** Прочитать Anthropic docs обязательные (skills, sub-agents, hooks, slash-commands).
- **День 2.** Переписать hooks (раздел 1). Проверить `git push -f` — блокируется.
- **День 3.** Подключить Atlassian Jira MCP + Context7 (раздел 2).
- **День 4.** Установить statusline (раздел 3).
- **День 5.** Сократить README, удалить лишние docs (раздел 4).

### Неделя 2 — продуктивность
- **День 6–7.** Прочитать исходники `anthropics/skills`, особенно `skill-creator/`, `pdf/`, `excel/`.
- **День 8.** Скопировать `skill-creator` к себе. Создать через него один новый skill (Oracle или ClickHouse).
- **День 9.** Прочитать «Building effective agents». Проверить свой `migration-reviewer` и stack-reviewers на tool-leak и stop conditions.
- **День 10.** Worktree isolation для `test-writer` (раздел 7).

### Неделя 3 — масштабирование
- **День 11.** Изучить `obra/superpowers`. Перенести идею TDD в `commands/feature.md`.
- **День 12.** Output style `backend-review` (раздел 6).
- **День 13.** Packaging как plugin (раздел 8).
- **День 14.** GitHub MCP + Postgres MCP.

### Постоянное (раз в 2 недели)

- Чек **Anthropic Changelog** (https://docs.claude.com/en/docs/claude-code/changelog) — обновления частые, поля frontmatter добавляются.
- Чек **Anthropic engineering blog** на новые техники.
- Чек **awesome-claude-code** на новые подборки.
- Раз в месяц — `python3 scripts/audit/extract.py && python3 scripts/audit/report_phase1.py` (мёртвые команды/агенты/skills видны в `data/tables.md`).

---

## 📌 Главная мысль

После Quick Wins конфиг **технически корректен**. Дальше ROI распределяется так:

1. **Hooks + Jira MCP** — самый большой выигрыш в день (часы экономии в неделю).
2. **Statusline** — самоконтроль над стоимостью.
3. **Plugin packaging** — переносимость между машинами.
4. **Skill-creator + новые доменные skills** — закроет пробелы (Oracle, ClickHouse, observability).
5. **Worktree + TDD-enforcer** — масштабирует параллельную работу.

Документация Anthropic и `anthropics/skills` — два источника, которые надо знать наизусть. Остальное — вариации.
