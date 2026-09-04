# My Claude Config

Личная конфигурация Claude Code: система работы агента, а не склад промптов.

Базовый принцип: **always-on слой маленький**, стековая специфика — в модульных
`skills/`, проектные ограничения — в локальном `CLAUDE.md` конкретного репозитория.

Настроено под три сценария:
- рабочие Java-сервисы (`Maven + Spring Boot + JPA + Oracle/PostgreSQL/ClickHouse + Kafka`)
- фронтенд на `Vue 3 + Vite + Pinia + TypeScript`
- побочные проекты на `Go`

## Быстрый старт

```bash
git clone <repo-url> ~/my-claude-config
cd ~/my-claude-config
cp workspace.conf.example workspace.conf   # поправь пути work/personal под себя
./scripts/setup-global.sh install          # dry-run: покажет план
./scripts/setup-global.sh install --apply  # реально установит в ~/.claude/
```

Установщик кладёт symlink на репозиторий в `~/.claude/my-claude-config` — по этому пути команды
и правила находят шаблоны и скрипты, поэтому репозиторий можно клонировать куда угодно.
Каталоги для проектов (`work`, `personal`) создаются из `workspace.conf`, а их пути попадают
в `~/.claude/workspace.md`. Что означают профили — `rules/09-project-profiles.md`.

В новом проекте: `claude` → `/onboard` — определит стек, задаст вопросы,
сгенерирует `CLAUDE.md` со строкой `Тип проекта: work|personal`.

## Структура

| Слой | Что это |
|---|---|
| `rules/` | тонкий always-on слой (Jira, staging-flow, Vault, TDD, язык, профили work/personal) |
| `commands/` | slash-команды: повторяемые сценарии (/feature, /review, /task…) |
| `agents/` | субагенты: reviewers, test-writers, migration-reviewer |
| `skills/` | стек- и доменные знания, грузятся по `description`/`paths` |
| `hooks/` | block-* (безопасность) и log-* (аналитика) |
| `templates/` | шаблоны CLAUDE.md и settings.json под профили |
| `scripts/` | установка (`setup-global.sh`), быстрый отчёт (`analyze-usage.sh`), месячный аудит (`audit/`) |
| `output-styles/` | стиль вывода главного агента |
| `docs/` | подробная документация |
| `tests/` | bash-тесты хуков и аналитики |

## Аналитика использования

Хуки пишут JSONL-логи в `~/.claude/logs/`. Два инструмента, оба без внешних зависимостей (jq / python3):

```bash
scripts/analyze-usage.sh 7                                   # быстрый отчёт за 7 дней в терминал
python3 scripts/audit/extract.py && python3 scripts/audit/report_phase1.py   # месячный аудит → docs/audit-2026-08/data/tables.md
```

Что смотреть раз в месяц (5 индикаторов, 20 минут) — `docs/audit-2026-08/05-growth.md`, раздел 7.
Полный аудит августа 2026, протокол «Рост» и отчёт: `docs/audit-2026-08/` (`report.html` — офлайн).

## Ежедневное использование

Шпаргалка по командам «что делать самому, что отдавать» — в начале [docs/WORKFLOW.md](docs/WORKFLOW.md).
Коротко: `/feature` — фича с планом; `/fix` — мелкий фикс и разбор бага (сначала твоя гипотеза, rule 08);
`/review` / `/review-mr` — ревью; `/task` — большая фича на несколько контекстов; `/plan`, `/arch` — план и
архитектура (сначала твой вариант); `/adr` — записать решение; `/jira` — задача для человека; `/reflect` —
после ручных правок; `/onboard` — новый репозиторий. Примеры по стекам: [docs/USAGE_GUIDE.md](docs/USAGE_GUIDE.md).

## MCP

Подключён один сервер, в user-scope (`~/.claude.json`, секция `mcpServers`):

| Сервер | Транспорт | Зачем |
|---|---|---|
| `context7` | HTTP, `https://mcp.context7.com/mcp` | актуальная документация библиотек: Spring Boot, JPA, Vue и прочее вместо памяти модели |

Восстановить на новой машине (если есть `claude` в PATH):

```bash
claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp
```

Без CLI — добавить в `~/.claude.json` ключ `mcpServers.context7` со значением
`{"type": "http", "url": "https://mcp.context7.com/mcp"}`.

Что сознательно НЕ подключено и почему — `CLAUDE.md`, раздел «Текущий фокус». Правило простое:
сервер добавляется под конкретную команду и по данным аудита, а не «на всякий случай»: описания
инструментов каждого сервера попадают в контекст каждой сессии.

## Развитие конфига

Куда класть новое (rule vs skill vs command vs agent), процесс добавления и
анти-паттерны: [docs/EXTENSION_GUIDE.md](docs/EXTENSION_GUIDE.md).
Порядок роста: project CLAUDE.md → skills → commands → agents → rules.

## Документация

| Файл | О чём |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | слои, поток токенов, как грузятся skills |
| [docs/WORKFLOW.md](docs/WORKFLOW.md) | ежедневный playbook |
| [docs/USAGE_GUIDE.md](docs/USAGE_GUIDE.md) | типовые сценарии по стекам |
| [docs/EXTENSION_GUIDE.md](docs/EXTENSION_GUIDE.md) | как расширять конфиг |
| [docs/HOOKS_GUIDE.md](docs/HOOKS_GUIDE.md) | справочник по хукам |
| [docs/ROADMAP.md](docs/ROADMAP.md) | история: что сделано (новое — только по данным аудита) |
| [docs/audit-2026-08/](docs/audit-2026-08/) | аудит использования, протокол «Рост», изменения конфига, отчёт |

Требования: `jq` (хуки, `analyze-usage.sh`), `trufflehog` (проверка секретов перед push),
`python3` ≥ 3.11 (`scripts/audit/`), macOS для уведомлений.

```bash
brew install jq trufflehog
```
