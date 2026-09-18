# my-claude-config

Личная конфигурация Claude Code: правила, команды, агенты, скилы, хуки и плейбук проектирования,
которые разворачиваются в `~/.claude/`. Это система работы агента, а не склад промптов.

Принцип: всегда включённый слой маленький (`rules/`), знания по стеку — в `skills/`, процессы —
в `commands/`, суждение — в `agents/`, ограждения — в `hooks/`, проектные ограничения — в локальном
`CLAUDE.md` каждого репозитория. Меняется по данным месячного аудита или по явному запросу с планом.

## Что где

| Каталог | Что это |
|---|---|
| `rules/` | всегда включённые правила: Jira и staging-flow, TDD и заморозка кейсов, язык, git и защищённые пути |
| `commands/` | slash-команды: `/quick`, `/fix`, `/feature`, `/task`, `/design`, `/review`, `/review-mr`, `/adr`, `/jira`, `/onboard`, `/explain`, `/reflect` |
| `agents/` | субагенты: planner, critic, implementer, architect, convention-reviewer, стек-ревьюеры, тест-райтеры, migration-reviewer |
| `skills/` | знания по стеку и процессу: Java-конвенция, Spring, тесты, JPA, интеграции, Vue, Go, DevOps, planning, design-docs, git-convention |
| `playbook/` | процесс проектирования команды: плейбук, нейминг, выжимки SDLC и рекомендаций, шаблоны документов |
| `docs/projects/` | артефакты проектирования по проектам: brief, design, plan, ADR, варианты |
| `hooks/` | ограждения (git, защищённые пути, формат коммита, заморозка тестов, секреты, rm -rf) и логи для аналитики |
| `shared/` | блоки для промптов команд: определение стека, карта слоёв |
| `scripts/` | установка, вспомогательные скрипты (`helpers/`), аналитика (`analyze-usage.sh`, `audit/`) |
| `templates/` | шаблоны `CLAUDE.md` и проектных `settings` по профилям для `/onboard` |
| `workspace.conf.example` | каталоги машины: work, personal, конвенция, плагин Sonar, ревью; копия `workspace.conf` в git не идёт |
| `tests/` | bash-тесты хуков и скриптов: `for t in tests/test-*.sh; do bash "$t"; done` |

Полное техническое описание — [docs/TECHNICAL.md](docs/TECHNICAL.md).

## Быстрый старт

```bash
git clone <repo-url> ~/dev/my-claude-config      # каталог любой
cd ~/dev/my-claude-config
cp workspace.conf.example workspace.conf         # каталоги этой машины
scripts/setup-global.sh install                  # dry-run: покажет план
scripts/setup-global.sh install --apply          # symlink ~/.claude/my-claude-config, хуки, permissions, excludes git
```

Команды и правила ссылаются на репозиторий только через `~/.claude/my-claude-config`, каталоги машины берут
из `~/.claude/workspace.md`, который установщик генерирует из `workspace.conf`. На второй машине те же три шага.

В новом проекте: `/onboard` — определит стек, задаст вопросы, сгенерирует `CLAUDE.md` и проектный
`.claude/settings.local.json`. Требуются `jq`, `perl`, `python3` ≥ 3.11; для Sonar — `SONAR_HOST_URL`
и `SONAR_TOKEN` в окружении.

## Лестница команд

| Команда | Когда | Что внутри |
|---|---|---|
| `/quick` | правка в одно предложение, поведение не меняется | ровно то, что написано; без тестов и ревью |
| `/fix` | баг или малое изменение поведения | причина до правки, падающий тест первым |
| `/feature` | фича в один контекст | план с кейсами, критик, согласование, TDD, Sonar, два ревьюера |
| `/task` | несколько фаз или контекстов | планировщик, критик, две остановки, исполнитель по фазам, Sonar, ревью |
| `/design` | проектирование по плейбуку: brief → design → план проекта | вариант автора, соревнование трёх вариантов с судьёй, ревью |
| `/review`, `/review-mr` | ревью своих изменений или MR коллеги | локальный Sonar, convention-reviewer и стек-ревьюер параллельно |
| `/adr`, `/jira`, `/onboard`, `/explain`, `/reflect` | записать решение, задача для человека, новый репозиторий, объяснение, урок из правок | |

Что делать самому: гипотеза при отладке, первый вариант решения, свои случаи для тестов, первый
проход по MR коллеги. Остальное отдаётся агенту.

Артефакты команд живут в репозитории проекта в `.claude/tasks/<ключ>/` (ключ — Jira-ID или имя ветки;
git игнорирует каталог глобально, ничего из него не удаляется): для чтения — `plan.md`, `tests.md`,
`review.md`, `summary.md`; для агентов — `agent/` (контекст, scope, критика, Sonar, сырые находки ревью).

## Ограждения

Агент не пушит, не мержит, не делает rebase и pull, не коммитит в master/staging; `.gitlab-ci.yml`,
`.gitlab/` и `helm/` меняет только по явной просьбе; правка закоммиченного теста или файла вне
scope задачи — вопрос; формат коммита проверяет хук. Подробности — правило 09 и `docs/TECHNICAL.md`.

## MCP

Один сервер в user-scope (`~/.claude.json`, секция `mcpServers`): `context7`, HTTP `https://mcp.context7.com/mcp`,
актуальная документация библиотек для `convention-reviewer` и `architect`. Восстановить на новой машине:

```bash
claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp
```

Другие серверы не подключены: описания инструментов каждого сервера попадают в контекст каждой сессии,
поэтому сервер добавляется под конкретную команду и по данным аудита, а не на всякий случай.

## Аналитика

Хуки пишут JSONL в `~/.claude/logs/`. Быстрый отчёт: `scripts/analyze-usage.sh 7`. Месячный аудит:
`python3 scripts/audit/extract.py && python3 scripts/audit/report_phase1.py` → `docs/audit-<месяц>/data/tables.md`.
Пять индикаторов месячной проверки — в `docs/TECHNICAL.md`. Отчёт августа 2026 — `docs/audit-2026-08/report.html`.
