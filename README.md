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
git clone <repo-url> ~/dev/my-claude-config
cd ~/dev/my-claude-config
./scripts/setup-global.sh install          # dry-run: покажет план
./scripts/setup-global.sh install --apply  # реально установит в ~/.claude/
```

В новом проекте: `claude` → `/onboard` — определит стек, задаст вопросы,
сгенерирует `CLAUDE.md`.

## Структура

| Слой | Что это |
|---|---|
| `rules/` | тонкий always-on слой (Jira, staging-flow, Vault, TDD, язык) |
| `commands/` | slash-команды: повторяемые сценарии (/feature, /review, /task…) |
| `agents/` | субагенты: reviewers, test-writers, migration-reviewer |
| `skills/` | стек- и доменные знания, грузятся по `description`/`paths` |
| `hooks/` | block-* (безопасность) и log-* (аналитика) |
| `templates/` | шаблоны CLAUDE.md и settings.json под профили |
| `scripts/` | установка (`setup-global.sh`), быстрый отчёт (`analyze-usage.sh`), месячный аудит (`audit/`) |
| `analytics/` | недельный пайплайн (остановлен на W28; кандидат на удаление — см. `docs/audit-2026-08/08-repo-review.md`) |
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

Требования: `jq` (хуки, `analyze-usage.sh`), `python3` ≥ 3.11 (`scripts/audit/`), macOS для уведомлений.
