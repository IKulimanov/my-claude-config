# Research Findings — что брать из публичных Claude Code репозиториев

> Создано 2026-05-17 на основе глубокого анализа superpowers, awesome-claude-code-toolkit, anthropic-skills, hooks-mastery, wshobson, 0xfurai-subagents.
> Парный документ к `ROADMAP.md`. Здесь — каталог идей с приоритетами, в `ROADMAP.md` — план их внедрения.

## Источники

| Репо | Что там | Url |
|---|---|---|
| **superpowers** | 15 process skills, hard-gate TDD методология | https://github.com/obra/superpowers |
| **awesome-claude-code-toolkit** (rohit) | 40 skills, 80+ agents, 8 категорий commands, hooks, MCP пресеты | https://github.com/rohitg00/awesome-claude-code-toolkit |
| **anthropic-skills** | skill-creator, pdf/xlsx/docx/pptx, doc-coauthoring, mcp-builder | https://github.com/anthropics/skills |
| **claude-code-hooks-mastery** (disler) | 9 hook lifecycle событий, TTS, 9 statuslines, 8 output-styles, meta-agent | https://github.com/disler/claude-code-hooks-mastery |
| **wshobson/agents** | 81 plugin-папок, packaged под `.claude-plugin/` | https://github.com/wshobson/agents |
| **0xfurai/subagents** | 138 узких технологических агентов | https://github.com/0xfurai/claude-code-subagents |
| **claude-memory-kit** | MEMORY.md + knowledge wiki + safety hooks | https://github.com/awrshift/claude-memory-kit |

---

## hooks

### Must-have

- **`smart-approve.py`** (rohit-toolkit, M) — декомпозиция compound bash. Парсит `cmd1 && cmd2 || cmd3` и проверяет каждую часть отдельно. Перестаёшь либо whitelistить весь bash, либо плодить permission prompts.
- **`commit-guard.js`** (rohit-toolkit, L) — валидация Conventional Commits. Блокирует `git commit -m "fix"`. Принуждает твой формат `{JIRA-CODE}: ...`.
- **`post-edit-check` chain** (rohit-toolkit, L-M) — lint + format + type-check + auto-test после Edit/Write. `auto-test.js` находит соседний `*Test.java` / `*_test.go` / `*.spec.ts` и запускает фокусированно. Самый высокий ROI из всех hooks.
- **`block-dev-server.js`** (rohit-toolkit, L) — запрет Spring Boot / Vite / Go HTTP-сервера вне tmux/screen. Спасает от orphan-процессов когда Claude завершает сессию. Нетривиально и реально помогает.
- **`block-md-creation.js`** (rohit-toolkit, L) — запрет создания `.md` вне `docs/`. Claude любит плодить `SUMMARY.md`, `NOTES.md`, `REPORT.md` где попало.
- **`prompt-check.js`** (rohit-toolkit, L) — детектор vague prompts. Ловит "fix this" / "make it better" и просит уточнение до того как Claude начал жечь токены.

### Advanced

- **`pre-compact.py`** (hooks-mastery, M) — сохраняет последние решения/блокеры в файл до compaction. Критично для миграционных задач.
- **`user_prompt_submit.py` с auto-naming + MEMORY.md inject** (hooks-mastery, M) — даёт сессии человекочитаемое имя и инжектит релевантные блоки из `MEMORY.md`.
- **`stop.py` с TTS-итогом** (hooks-mastery, M-H) — произносит вслух что сделано (ElevenLabs / OpenAI / pyttsx3 fallback). Для длинных background-задач — позволяет уйти от экрана.
- **`subagent_start.py` / `subagent_stop.py`** (hooks-mastery, M) — телеметрия subagent-ов. Дополнение к моему `log-subagent.sh`.
- **`learning-log.js`** (rohit-toolkit, L) — пишет daily-log в Obsidian-friendly markdown. Готовый источник для note-taking flow.

### Skip

`suggest-compact.js`, GenUI-only hooks, чистый TTS (notify-stop уже есть).

---

## rules

Публичные репо мало предлагают. Главный паттерн — **"iron laws"** из superpowers:

- **«NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST»** (superpowers `test-driven-development`, L)
  Добавить как `rules/06-tdd-discipline.md`. Для Go side-проектов — жёстко; для Spring — оставить per-skill.
- **«NO FIXES WITHOUT ROOT CAUSE INVESTIGATION»** (superpowers `systematic-debugging`, L)
  `rules/07-debug-discipline.md`. Запрещает Claude «починить» симптом не разобравшись.
- **«BEFORE CLAIMING DONE: IDENTIFY → RUN → READ → VERIFY»** (superpowers `verification-before-completion`, L)
  Запрещает фразы "should work", "probably". Лечит главную проблему: «отрапортовал готово, реально не запускал».
- **«Запрещено создавать `.md` вне `docs/`»** (rohit-toolkit, L) — можно как rule + как hook.

---

## skills

### Процессные (superpowers — must-have целиком)

- **test-driven-development** (L) — RGR с anti-rationalization таблицей. Java/JUnit и Go/testing без адаптации.
- **systematic-debugging** (L) — 4 фазы Root Cause. Особенно ценно для multi-component систем (Spring → Kafka → API).
- **verification-before-completion** (L) — gate function перед claim done.
- **brainstorming** (M) — hard-gate: нет имплементации без approved design doc. Для фазы «планирую».
- **writing-plans** (L) — разбивает spec на 2-5 минутные tasks.
- **subagent-driven-development** (H) — fresh-context subagent на каждый task.
- **writing-skills** (M) — **meta-skill, TDD применённый к skill-документам**. Жёстче чем anthropic skill-creator. Главная находка.

### Knowledge / learning

- **claude-memory-kit** (rohit-indexed, M) — `MEMORY.md` (hot cache) + knowledge wiki с `[[wikilinks]]` + `/close-day`. У меня уже есть `MEMORY.md`, добавится wiki-слой.
- **continuous-learning** (rohit-toolkit, L) — yaml entries с confidence-scoring 0.0-1.0 и +/- correction loop. **Готовая замена Anki без Anki** — confidence играет роль interval, low-confidence карточки всплывают чаще.
- **deep-dive** (rohit-toolkit, M) — DAG-based research через parallel subagents. Идеально для технического ресерча перед feature или блог-постом.

### Writing / docs

- **doc-coauthoring** (anthropic-skills, L) — 3-stage workflow (Context Gathering → Refinement → Reader Testing). Адаптируется под PRD/RFC/блог-посты.
- **pdf / docx / pptx** (anthropic-skills, L) — экспорт markdown в Office/PDF для блога/публикации.

### Технологические

- **springboot-patterns** (rohit-toolkit, L) — layered architecture, `@ControllerAdvice`, security filter chain.
- **postgres-optimization** (rohit-toolkit, L) — index strategies, EXPLAIN ANALYZE, JSONB. Применимо из HikariCP и `pgx`.

### Meta

- **skill-creator** (anthropic-skills, L) — генерация skill-ов с правильными "pushy" descriptions, eval-viewer.
- **mcp-builder** (anthropic-skills, M) — 4-фазный гайд по созданию своих MCP.

### Skip

Все языковые «best-practices» (есть свои), `brand-guidelines`, `theme-factory`, `canvas-design`, `slack-gif-creator`.

---

## agents (subagents)

### Орchестрация

- **workflow-director** (rohit-toolkit, opus, H) — 5 фаз с checkpoint-management и rollback. Для миграций (Spring 2→3, Java 17→21, Oracle→PostgreSQL).
- **knowledge-synthesizer** (rohit-toolkit, opus, M) — pyramid principle (вывод → доказательства → темы), разделяет facts/inferences/opinions, ищет contradictions. **Идеален для технического ресерча и блог-постов.**
- **context-manager** (rohit-toolkit, opus, M) — трекает token usage, бюджет 40/30/20/10 (Critical/Important/Reference/Reserve).

### Research (для не-кодинга)

- **technology-scout** (rohit-toolkit, M) — «что нового вышло по X».
- **trend-analyst** (rohit-toolkit, M) — для блог-постов о трендах.
- **academic-researcher** (rohit-toolkit, M) — для технического ресерча.

### DX

- **legacy-modernizer** (rohit-toolkit, L) — для Java 8→17, Spring 4→6 миграций.

### Meta

- **meta-agent** (hooks-mastery, opus, L) — WebFetch свежей docs.anthropic.com → генерирует готовый `.claude/agents/<name>.md`. **Самый прагматичный meta-tool.**

### Skip

`java-architect`/`golang-developer`/`vue-specialist` — дубликаты существующих. `chaos-engineer` — не нужно. Узкие фреймворки (gin-expert, fiber-expert) — пока не нужно.

---

## commands (slash commands)

### Knowledge / workflow

- **`/adr <topic>`** (rohit-toolkit, L) — генерит `docs/adr/NNNN-<slug>.md` со Status/Context/Decision/Consequences. **Прямо под планирование/документирование.**
- **`/memory-bank`** (rohit-toolkit, L) — обновляет project `CLAUDE.md` с decisions / problems / patterns из сессии.
- **`/checkpoint`** (rohit-toolkit, L) — `git diff --stat` + summary + сохраняет в `.claude/checkpoints/<ts>.md`.
- **`/wrap-up`** (rohit-toolkit, L) — конец сессии: extract learnings + commit handoff.
- **`/close-day`** (claude-memory-kit, M) — капчуришь весь день в knowledge wiki одной командой.

### Documentation

- **`/onboard`** (rohit-toolkit, L) — сканирует `pom.xml`/`go.mod`/`docker-compose.yml` и пишет `docs/onboarding.md`. Альтернатива той `/onboard` команде что мы обсуждали ранее — можно взять как стартовую базу.
- **`/diagram`** (rohit-toolkit, L) — Mermaid/C4 из существующего кода. Для блог-постов и архитектурных доков.
- **`/api-docs`** + **`/doc-gen`** (rohit-toolkit, L).

### Architecture

- **`/plan <feature>`** (rohit-toolkit, L) — 5-фазный template, 3-10 шагов, каждый deployable. Альтернатива существующему `commands/plan.md` — посмотреть и слить лучшее.

### Git

- **`/pr-create`** + **`/changelog`** + **`/release`** + **`/commit`** + **`/worktree`** (rohit-toolkit, L).

### Refactoring

- **`/dead-code`** (rohit-toolkit, L) — особенно полезно для длинных Java-кодовых баз.
- **`/simplify`** (rohit-toolkit, L).

### Context

- **`/context-save`** + **`/context-restore`** (wshobson `plugins/context-management/`, M) — явное сохранение между сессиями.

### Skip

Дубликаты существующих (`/test`, `/review`, `/debug`). `/team-*` команды — это под superpowers subagent-flow, отдельная история.

---

## MCP servers

### Must-have

- **Atlassian Jira MCP** — `@atlassian/mcp-server` (L) — самая высокая ROI. Чтение тикетов, комменты, статусы.
- **GitHub MCP** — `@modelcontextprotocol/server-github` (L) — PR/issues без `gh` CLI.
- **Context7** ✅ установлен 2026-05-17 — `npx -y @upstash/context7-mcp` (L) — up-to-date docs для Spring/Hibernate/Vue/Go по версии.
- **filesystem** + **fetch** — базовая инфраструктура (L).

### Knowledge / writing

- **Obsidian MCP** — `mcp-obsidian` (community, M) — подключается к Local REST API plugin vault. Claude читает/пишет в vault. **Game-changer для note-taking flow.**
- **memory MCP** — `@modelcontextprotocol/server-memory` (L) — persistent knowledge graph (entities + relationships).

### Backend dev

- **postgres MCP** — `@modelcontextprotocol/server-postgres` (L) — schema introspection + queries для dev-БД.
- **sentry MCP** — `@sentry/mcp-server` (L) — отладка прода, error groups, стектрейсы.

### Research / writing

- **brave-search** + **firecrawl** + **fetch** (L) — research стек.
- **bgpt MCP** (L) — научные papers с full-text. Уникальное для technical research.

### Skip сразу

slack, redis, docker MCP, puppeteer — добавлять по нужде.

---

## output styles

- **Standard markdown / bullet-points** — дефолт.
- **`tts-summary`** (hooks-mastery, M) — после ответа произносит итог. Для фоновой работы.
- **`GenUI`** (hooks-mastery, M) — HTML5 в `/tmp` с автооткрытием. Полезно для архитектуры/диаграмм.
- **`backend-review` (свой)** — обязательные секции Risks / Rollback / Validation (уже в ROADMAP).

---

## workflows / методологии

- **superpowers 7-фазный TDD** — brainstorming → writing-plans → subagent-driven-development → TDD → verification → review → finishing-branch. Самая жёсткая методология в публичном поле.
- **DAG-based deep research** (rohit-toolkit `deep-dive`) — для технического ресерча перед статьёй.
- **Two-layer memory** (claude-memory-kit) — `MEMORY.md` hot cache + knowledge wiki с wikilinks.

### Skip

BMAD-METHOD — продвигает agile-роли (Analyst, PM, Architect…), для personal config не нужно.

---

## meta-tools

- **meta-agent** (hooks-mastery, L) — генерит `.claude/agents/<name>.md` с актуальной docs.anthropic.com. Взять сразу.
- **writing-skills** (superpowers, M) — жёсткий генератор skill-документов через pressure-test scenarios.
- **skill-creator** (anthropic-skills, L) — попроще, проверен официально.
- **mcp-builder** (anthropic-skills, M) — когда буду делать свой MCP.

---

## plugin packaging

| Стиль | Применимость |
|---|---|
| **superpowers-стиль** | single `plugin.json` + `skills/` + `hooks/hooks.json` + multi-tool sync через `scripts/`. **Самый чистый, рекомендую.** |
| **wshobson-стиль** | monorepo с N plugin-папками. Если захочу публиковать тематически (`java-spring-toolkit`). |
| **hooks-mastery-стиль** | однопроектный `.claude/`, не plugin. Это мой текущий стиль. |

---

## statusline

В hooks-mastery 9 версий на `uv run`. Показывают: branch + dirty, model, tokens, session-time, current agent, cost-tracker.

**Альтернативы готовые:**
- **`ccstatusline`** — проще, фокус на rate-limit usage 5h/7d. Рекомендую.
- **`claude-powerline`** — powerline-стиль, цвета.

---

## Learning / note-taking / writing — отдельный стек

Самая интересная часть под профиль «не только разрабатываю, но и изучаю, планирую, пишу»:

| Инструмент | Источник | Зачем |
|---|---|---|
| **claude-memory-kit** | rohit-toolkit | MEMORY.md + knowledge wiki + `/close-day` |
| **continuous-learning** skill | rohit-toolkit | confidence-scoring → spaced repetition без Anki |
| **deep-dive** skill | rohit-toolkit | DAG-research через parallel subagents — для статей |
| **doc-coauthoring** skill | anthropic-skills | 3-stage workflow для PRD/RFC/блог-постов |
| **knowledge-synthesizer** agent | rohit-toolkit | Pyramid principle, разделение facts/inferences/opinions |
| **technology-scout** agent | rohit-toolkit | «Что нового по X» — для блога |
| **pdf/docx/pptx** skills | anthropic-skills | Экспорт writing в полированные форматы |
| **Obsidian MCP** | community | Прямой доступ к vault — критично |
| **`/adr`** + **`/checkpoint`** + **`/wrap-up`** | rohit-toolkit | Daily capturing workflow |
| **learning-log** hook | rohit-toolkit | Автозапись daily-log в Obsidian-friendly markdown |
| **bgpt MCP** | community | Full-text научных papers |

---

## Приоритет внедрения

### Неделя 1 — фундамент (быстрые победы)
1. **Context7 + Atlassian Jira MCP + GitHub MCP** — MCP-стек.
2. **statusline** (`ccstatusline`) — самоконтроль над токенами.
3. **iron-law rules** из superpowers (3 правила) — добавить в `rules/`.

### Неделя 2 — методология
4. **superpowers целиком** — test-driven-development, systematic-debugging, verification-before-completion, brainstorming, writing-plans, writing-skills.
5. **meta-agent** (hooks-mastery) — для быстрого создания новых агентов.

### Неделя 3 — learning/writing/knowledge
6. **Obsidian MCP** + **claude-memory-kit** + **continuous-learning** skill.
7. **knowledge-synthesizer** + **deep-dive** + **doc-coauthoring** + **technology-scout** — стек для статей и ресерча.
8. **anthropic pdf/docx/pptx** skills — для экспорта.

### Неделя 4 — продвинутые hooks и команды
9. **smart-approve** + **post-edit-check chain** + **block-dev-server** + **block-md-creation** + **prompt-check**.
10. **commands:** `/adr`, `/memory-bank`, `/checkpoint`, `/wrap-up`, `/onboard`, `/dead-code`.

---

## Главные находки, которых раньше не было

1. **superpowers `writing-skills`** — TDD применённый к skill-документам (pressure scenarios → baseline failure → write → verify).
2. **hooks-mastery `meta-agent`** — WebFetch свежей doc + генерация агента.
3. **rohit-toolkit `deep-dive`** — DAG-decomposed research через parallel subagents.
4. **rohit-toolkit `continuous-learning`** — confidence-scoring как замена Anki.
5. **rohit-toolkit `block-dev-server.js`** — запрет dev-server вне tmux (orphan-процессы).
6. **bgpt MCP** — full-text научных papers.
7. **Obsidian MCP** + **claude-memory-kit** — пара которая закрывает note-taking flow без скриптов.
