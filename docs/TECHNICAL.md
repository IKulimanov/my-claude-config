# Техническое описание my-claude-config

Обновлено 2026-09-18 после перестройки (план — `docs/refactor-2026-09/plan.html`).

## 1. Каталоги

```
rules/            9 правил, всегда включены через ~/.claude/CLAUDE.md (@import)
commands/         12 slash-команд
agents/           12 субагентов
skills/           15 скилов (SKILL.md + references/)
playbook/         плейбук проектирования, нейминг, выжимки PDF, templates/
shared/           блоки для промптов команд: stack-detection.md, affected-layers.md
hooks/            settings.json (хуки + permissions) и scripts/ (ограждения, логи, lib/)
scripts/          setup-global.sh, install-hooks.sh, analyze-usage.sh, gen-convention-checklist.sh,
                  helpers/ (скрипты для команд), lib/, audit/ (месячный аудит)
templates/        CLAUDE.<profile>.md.template, settings.<profile>.json.template
workspace.conf.example  каталоги машины: work, personal, конвенция, плагин Sonar, ревью; копия workspace.conf не в git
docs/             TECHNICAL.md, projects/<проект>/, audit-<месяц>/report.html
tests/            bash-тесты хуков и скриптов
output-styles/    personal.md — стиль вывода главного агента
statusline/       statusline.sh
```

## 2. Как собирается контекст

- `scripts/setup-global.sh install --apply` делает symlink `~/.claude/{skills,agents,commands,output-styles}`
  на каталоги репозитория, генерирует `~/.claude/CLAUDE.md` с `@import` каждого `rules/*.md` (управляемый
  блок), ставит хуки и `permissions` через `install-hooks.sh`, `outputStyle`, `statusLine`, `cleanupPeriodDays`
  и управляемый блок в глобальном excludes git (`.claude/tasks/`, `.claude/settings.local.json`, `.ai/`;
  файл — `core.excludesFile` или `~/.config/git/ignore`). Ещё два компонента отвязывают конфиг от машины:
  `config` — symlink `~/.claude/my-claude-config` на репозиторий, через который команды и правила читают
  `shared/`, `playbook/`, `scripts/helpers` (клон может лежать где угодно); `workspace` — `~/.claude/workspace.md`
  из `workspace.conf` (каталоги work и personal, конвенция, плагин Sonar, ревью), подключается в управляемый блок.
- Symlink означает: правка в репозитории живёт в следующей сессии сразу. Большие переделки — в worktree
  на ветке, слияние в `main` включает их.
- Правила читаются всегда (9 файлов, ≈ 21 КБ). Правило 10 задаёт профиль: строка `Тип проекта:` в `CLAUDE.md`
  проекта (пишет `/onboard`), иначе каталог work из `workspace.md`, иначе personal — без Jira, Sonar и канона. Скилы грузятся по описанию и по `paths:` (например,
  `java-service-convention` на `**/*.java`), явно из команд и через `skills:` у агентов. Главный агент сам
  скилы почти не берёт — поэтому команды называют нужные скилы явно.
- `shared/stack-detection.md` — общий блок: стек, профиль work или personal (правило 10), какие скилы
  грузить; `shared/affected-layers.md` — карта слоёв для планов.
- `playbook/` читают `/design`, `/jira`, `/adr`, `planner`; шаблоны документов — `playbook/templates/`.

## 3. Команды

| Команда | Когда | Поток | Подагенты |
|---|---|---|---|
| `/quick` | точечная правка по прямому указанию | ровно то, что написано; без плана, тестов, ревью | 0 |
| `/fix` | баг, малое изменение поведения | причина до правки (rule 08), RED → GREEN → REFACTOR | 0–1 |
| `/feature` | фича в один контекст | стек → план с кейсами (skill `planning`) → critic → согласование → TDD → Sonar → два ревьюера | critic, тест-райтер, два ревьюера |
| `/task` | несколько фаз или контекстов | сортировка → Explore → planner → critic → **согласование плана** → кейсы → critic → **согласование кейсов** → implementer по фазам в границах `scope.txt` → Sonar → critic + два ревьюера → фиксер | 4–9 |
| `/design` | brief → design → план проекта | шаг по статусам файлов в `docs/projects/<проект>/`; вариант автора; соревнование трёх `architect` с судьёй; ревью | architect ×1–4 |
| `/review` | ревью своих изменений | Sonar → convention-reviewer ∥ стек-ревьюер → `.claude/tasks/<ключ>/review.md` | 2–3 |
| `/review-mr` | ревью MR коллеги против master | glab-дифф → convention-reviewer ∥ java-reviewer → файл в `~/docs/work/reviews/` | 2 |
| `/adr` | записать решение | шаблон репозитория или `playbook/templates/adr-template.md` | 0 |
| `/jira` | задача для человека | `playbook/templates/task-template.md`, Дано/Когда/Тогда | 0 |
| `/onboard` | новый репозиторий | стек, вопросы, `CLAUDE.md` из шаблона, `.claude/settings.local.json` с ask-списком | 0 |
| `/explain` | объяснить технологию или паттерн | структура «что → зачем → как → когда → пример → ошибки» | 0 |
| `/reflect` | после ручных правок агентского результата | размер правки, один урок в память, скил или правило | 0 |

Остановки в `/task` — только две согласования, стоп-точки `[#]` в плане и `[!]` от агента.
Статусы шагов и кейсов меняются скриптами `plan-status.sh`, `tests-status.sh`.

## 4. Агенты

| Агент | Модель / усилие / maxTurns | Скилы | Кто зовёт |
|---|---|---|---|
| `planner` | opus / high / 250 | planning | `/task`: план и scope, кейсы, правка по критике |
| `critic` | opus / high / 150 | planning (+ java-patterns по промпту) | `/task` ×3, `/feature` ×1 |
| `implementer` | inherit / high / 300, без Agent | стек-скил грузит сам | `/task` по фазам, фиксер |
| `architect` | opus / high / 200 | design-docs, java-patterns, integration-patterns, jpa-db-review | `/design` |
| `convention-reviewer` | sonnet / medium / 150 | java-service-convention, git-convention | `/review`, `/review-mr`, `/task` |
| `java-reviewer` | opus / high / 250 | jpa-db-review, integration-patterns, testing | там же |
| `go-reviewer`, `vue-reviewer` | opus / high / 250 | go-best-practices; vue-frontend | там же |
| `test-writer`, `go-test-writer`, `vue-test-writer` | sonnet / medium / 150 | testing; go-best-practices; vue-frontend | RED-тесты по `tests.md` |
| `migration-reviewer` | opus / high / 150 | jpa-db-review | миграции, индексы, JPA-маппинг |

Встроенные: `Explore` — контекст для `/task`; `general-purpose` — разовые задачи. Встроенный `Plan` не
используется: у него нет Write, планы уходили через heredoc. Потолки `maxTurns` — максимум по логам × 1,5;
поле пока не соблюдается Claude Code, пересмотр 2026-10-17.

## 5. Скилы

| Скил | Триггер | Что |
|---|---|---|
| `java-service-convention` | `**/*.java`, явно | профиль work → канон по пути из `~/.claude/workspace.md`; `references/sonar-rules.md` — выжимка правил CI Sonar (`gen-convention-checklist.sh`) |
| `spring-best-practices`, `java-patterns`, `testing`, `jpa-db-review`, `integration-patterns` | описание, `paths` | Spring, паттерны и SOLID, тесты Java, JPA и БД, Kafka и REST |
| `go-best-practices`, `vue-frontend` | `**/*.go`; `**/*.vue` | Go и Vue 3 |
| `docker`, `gitlab-ci`, `helm`, `kubernetes` | пути манифестов | DevOps; правка CI и helm — только по явной просьбе |
| `planning` | явно из команд | как планируем: шаги, фазы, простота, кейсы, оценка плана |
| `design-docs` | `/design`, разговоры о дизайне | шаги плейбука, чек-листы, позиции для вариантов, вопросы ревью |
| `git-convention` | ветки, коммиты | форматы веток и коммитов, staging-flow, что запрещено |

## 6. Хуки и permissions

`hooks/settings.json` устанавливается `scripts/install-hooks.sh --write`: секция `hooks` заменяется целиком,
`permissions.allow`, `deny` и `ask` объединяются с существующими без дублей. Логи —
`~/.claude/logs/*.jsonl` (`tools`, `prompts`, `sessions`, `subagents`, `stops`, `blocks`, `instructions`).

| Хук | Событие | Решение |
|---|---|---|
| `guard-git.sh` | PreToolUse Bash | deny: push, merge, rebase, pull, checkout/switch и commit на master/main/staging/prod*, `--no-verify`; ask: amend, reset --hard, clean -f, branch -D, stash drop, checkout/restore файлов |
| `check-commit-msg.sh` | PreToolUse Bash | deny с подсказкой формата: рабочий проект `JIRA-ID: Описание…` (ID из имени ветки), личный `тип(scope): описание…`; русский; ≤ 72; без трейлеров |
| `guard-paths.sh` | Edit, Write, MultiEdit, Bash | ask на запись в `.gitlab-ci.yml`, `.gitlab/`, `helm/` |
| `guard-tests.sh` | Edit, Write, MultiEdit, Bash | ask на правку тест-файла, который есть в git и не изменён относительно HEAD |
| `guard-scope.sh` | Edit, Write, MultiEdit | ask на запись в файл репозитория вне `agent/scope.txt` задачи текущей ветки, пока scope активен; Bash-записи не смотрит |
| `block-destructive.sh` | Bash | deny: `rm -rf` вне `target/`, `build/`, `dist/`, `node_modules/` и scratch-каталогов; DROP/TRUNCATE, chmod 777, mkfs |
| `block-secrets.sh` | Read, Edit, Write, MultiEdit, Bash | deny: чтение `.env` и вариантов, ключей `.pem`/`.p12`/`.jks`, `~/.ssh`, `~/.aws`, `~/.gnupg`, kubeconfig; проверяются только аргументы-пути: имя в `ls`, `find -name`, `--exclude`, шаблон `grep` проходят; `.envrc` и `node_modules/` безопасны |
| `log-*.sh`, `notify-stop.sh` | все события | логи для аналитики (вопросы `AskUserQuestion` пишутся текстом), уведомление на Stop; помечены `async` (замер 2026-09-04: 51 мс на хук, два на вызов); журнал больше 20 МБ (`CLAUDE_LOG_MAX_MB`) отрезается в `<имя>-<дата>.jsonl`, срезы не удаляются |

`permissions.allow`: только чтение — `git status/diff/log/branch/show`, `ls`, `rg`, `find`. `permissions.deny`:
`Bash(git push*)`, `Bash(git merge *)`, `Bash(git rebase *)`, `Bash(git pull*)` и `Read` секретов (`.env`, `~/.ssh/**`,
`~/.aws/credentials`, `~/.kube/config`, `~/.gnupg/**`, `*.pem`, `*.p12`, `*.jks`, `id_rsa`, `id_ed25519`) — второй слой за хуком.
`permissions.ask`: Edit/Write/MultiEdit на `**/.gitlab-ci.yml`, `**/.gitlab/**`, `**/helm/**`. Проектные
добавки — `.claude/settings.local.json` (пишет `/onboard` из `templates/settings.<profile>.json.template`).
Хуки — код: у каждого есть тест в `tests/`; перед сопоставлением вырезаются `cd`, `git -C`, тела heredoc.

## 7. Политика git и коммитов

Правило 09. Агент: локальная ветка от master, `add`, `commit`, `stash`, `fetch`, `diff`, `log`.
Пользователь: push, merge, rebase, pull, MR, переключение на защищённые ветки. Ветка:
`{type}/{JIRA-ID}-{описание}`; коммит рабочего проекта `ORSP-2864: Добавить ретрай отправки в Kafka`
(ID совпадает с веткой; ветка без ID — без ID), личного `feat(api): добавить ретрай отправки в Kafka`
(типы feat, fix, docs, refactor, test, chore, build, ci, perf). Трейлеры `Co-Authored-By` и подобные
запрещены. Подробности — скил `git-convention`.

## 8. Артефакты

Каталог задачи — `.claude/tasks/<ключ>/` в репозитории проекта. Ключ — Jira-ID из имени ветки, иначе имя
ветки без типового префикса (`feature/export-csv` → `export-csv`, `release/1.2` → `release-1.2`); доработки
той же ветки — `<ключ>-2`, `-3`. Создаёт `scripts/helpers/ai-init.sh`: без аргументов — последний каталог
текущей ветки, `--new` — доработка, `<имя>` — явный ключ (ветка коллеги для `/review-mr`); старый `.ai/`
он переносит сюда сам. Git игнорирует `.claude/tasks/` через глобальный excludes (`setup-global.sh`,
компонент `git-excludes`), `.gitignore` проектов не трогается. Артефакты не удаляются, скрипта чистки нет.

| Для кого | Файлы |
|---|---|
| человек, `<ключ>/` | `plan.md` (шаги со статусами, журнал), `tests.md` (кейсы), `review.md` (итог ревью: закрыто, осталось, отклонено), `summary.md` (итог задачи; его наличие = задача завершена) |
| агенты, `<ключ>/agent/` | `context.md` (≤ 300 строк), `scope.txt` (куда можно писать), `critique1..3.md`, `sonar.md`, `review-raw-1..2.md` |
| репозиторий | `.claude/tasks/about.md` — слепок проекта, пишет Explore |

`/feature` пишет `plan.md` (кейсы внутри), `review.md`, `summary.md`, `agent/{critique1,sonar}.md`, `agent/scope.txt`;
`/review` — `review.md`, `agent/sonar.md`. Форматы: `playbook/templates/plan-template.md` (статусы
`[ ] [~] [x] [!] [#]`, ≤ 150 строк), `tests-template.md` (Дано/Когда/Тогда, статусы `[ ] [~] [x] [!]`).

Границы задачи. Требования агенты берут только из `plan.md`, `tests.md` и `agent/context.md`; недостающее —
вопрос `[!]`, а не допущение. Писать можно только в файлы из `agent/scope.txt` (первая строка —
`# scope: active|done`, дальше пути и маски от корня: `*` захватывает `/`, строка с `/` на конце — каталог).
Хук `guard-scope.sh` спрашивает на запись вне списка, пока scope активен; список ведёт
`scripts/helpers/scope.sh <каталог> add|done|active|check`, расширяет его оператор, не исполнитель.

`docs/projects/<проект>/` (`/design`): `00-brief.md`, `01-design.md`, `02-plan.md`, `adr/`, `options/`
(варианты A–C и `verdict.md`), `assets/`. Каркас — `scripts/helpers/design-init.sh <проект>`.

## 9. Sonar локально

Сервер — SonarQube Community Build, режим MQR, собственный профиль на базе плагина
`convention-sonar-rules-plugin` (репозиторий правил `nurtelecomconventionjavarules`). Community Build не
анализирует ветки, поэтому `scripts/helpers/sonar-local.sh` анализирует рабочее дерево в песочный проект
`<ключ>-local` (ключ из `sonar-project.properties`, иначе `kg.nurtelecom:<artifactId>`), ждёт задачу CE
и печатает issues по изменённым файлам: собственные правила первыми, встроенные по серьёзности.
Настройка один раз на проект: `sonar-local.sh --init` (нужны права Execute Analysis и Create Projects,
профиль конвенции привязывается автоматически). `sonar-issues.sh <ключ>` — issues любого проекта,
`sonar-rule.sh <код>` — текст правила. Токен и адрес — только `SONAR_HOST_URL`, `SONAR_TOKEN` в окружении.

Политика исправлений (`/task` шаг 10, `/review`): собственные правила и BLOCKER/HIGH — исправить;
MEDIUM механические — исправить, требующие переделки — спросить; LOW, INFO и спорные — один вопрос
пакетом. Не больше двух кругов. Quality gate CI остаётся финальным вердиктом.

## 10. Скрипты

| Скрипт | Назначение |
|---|---|
| `scripts/setup-global.sh status\|install\|uninstall [--apply]` | развернуть или откатить конфиг: компоненты skills, agents, commands, hooks, claude-md, output-styles, statusline, git-excludes, config, workspace |
| `scripts/install-hooks.sh [--write]` | хуки и permissions в `settings.json` (`CLAUDE_SETTINGS_TARGET` для тестов) |
| `scripts/helpers/ai-init.sh`, `scope.sh`, `design-init.sh` | каталог задачи `.claude/tasks/<ключ>/` (ключ из ветки, `--new`, перенос `.ai/`; `scripts/lib/task-dir.sh`), scope файлов задачи, каркас `docs/projects/` |
| `scripts/helpers/plan-status.sh`, `tests-status.sh` | статусы шагов и кейсов без чтения файла моделью |
| `scripts/helpers/test-summary.sh <команда>` | только упавшие тесты и итог; полный вывод в файл |
| `scripts/helpers/sonar-local.sh`, `sonar-issues.sh`, `sonar-rule.sh`, `sonar-rules-for-diff.sh` | раздел 9; выжимка правил по составу диффа, когда сервер недоступен |
| `scripts/analyze-usage.sh [дней]` | быстрый отчёт по логам |
| `scripts/audit/extract.py`, `report_phase1.py` | месячный аудит: классификация промтов, итерации, мёртвые команды, rule 08 |
| `scripts/gen-convention-checklist.sh` | перегенерация `sonar-rules.md` из плагина (только рабочая машина) |

## 11. Аналитика и месячная проверка

Раз в месяц (20 минут): `python3 scripts/audit/extract.py && python3 scripts/audit/report_phase1.py`
→ `docs/audit-<месяц>/data/tables.md` (каталог в `.gitignore`), плюс встроенные `/insights` и `/usage`.

| Индикатор | Откуда | Цель |
|---|---|---|
| доля отладочных и проектных постановок со своей гипотезой | `tables.md`, «Rule 08 baseline» | ≥ 40% |
| попадание гипотезы (совпала / всего) | строки «Гипотеза пользователя» в ответах | ≥ 50% |
| принято без правок (`reflect: 0` / все `reflect`) | `/reflect` | тренд |
| доля «проведи анализ»-постановок | `tables.md` | ≤ 6% |
| дни без агента в месяц | «Объём по неделям» | ≥ 4 |

Дополнительно после перестройки: блокировки по новым хукам (`blocks.jsonl`, поле `kind`), число `[!]`
и `[#]` в планах, итерации ревью, доля замечаний критика «по желанию», доля вопросов по Sonar.
Контрольные точки: 2026-10-17 (`maxTurns`), 2026-11-15 (всё остальное).

## 12. Куда класть новое и конвенция авторинга

- `rules/` — только то, что нужно почти в каждом проекте, коротко и стабильно; всегда включено.
- `skills/` — знания по стеку или процессу, грузятся по описанию и путям; узкие лучше одного большого.
- `commands/` — повторяемый процесс с устойчивой последовательностью шагов.
- `agents/` — роль с суждением, свежим контекстом или ограничением инструментов.
- `hooks/` — ограждение с простым надёжным правилом и тестом; текст правила — просьба, хук — гарантия.
- Скрипт вместо промпта, когда шаги детерминированы (`scripts/helpers/`); по TDD, с тестом в `tests/`.

Frontmatter: команда — `description`, `argument-hint`, `allowed-tools`, `disable-model-invocation`;
агент — `name`, `description`, `tools`, `disallowedTools`, `model` (`opus`, `sonnet`, `inherit`), `effort`,
`maxTurns`, `skills`; скил — `name`, `description`, `paths`. Русский в чате, комментариях, коммитах,
документации; без ИИ-слопа (правило 07).

## 13. Тесты репозитория

```bash
for t in tests/test-*.sh; do bash "$t"; done
```

Каждый хук и скрипт покрыт тестом (`tests/lib/hooktest.sh` — общие функции для PreToolUse-хуков;
`test-sonar-scripts.sh` поднимает поддельный сервер Sonar). Тесты не трогают `~/.claude/`: цели
переопределяются переменными `CLAUDE_LOG_DIR`, `CLAUDE_SETTINGS_TARGET`, `CLAUDE_HOME`,
`CLAUDE_WORK_ROOT`, `DESIGN_PROJECTS_ROOT`, `SONAR_RULES_FILE`; тесты `git-excludes` и `workspace` подменяют `HOME` и
`XDG_CONFIG_HOME` (git читает конфиг из временного каталога, каталоги машины создаются там же); для хуков —
`CLAUDE_WORKSPACE_CONF`, `CLAUDE_LOG_MAX_MB`.
