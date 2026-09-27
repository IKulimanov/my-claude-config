# CLAUDE.md — my-claude-config

Мета-репозиторий: личная конфигурация Claude Code (правила, команды, агенты, скилы, хуки, плейбук),
которая разворачивается в `~/.claude/`. Рантайма, БД и API здесь нет — markdown и bash. Техническое
описание — `docs/TECHNICAL.md`; читай его перед нетривиальной правкой.

## Принципы

- Всегда включённый слой (`rules/`) маленький; стек — в `skills/`, процессы — в `commands/`, суждение —
  в `agents/`, ограждения — в `hooks/`. Конфиг меняется по данным месячного аудита или по явному запросу
  с планом; удалять предпочтительнее, чем добавлять.
- Хуки и скрипты — код: сначала падающий тест в `tests/`, потом реализация (правило 06). Скрипты:
  `set -euo pipefail`, dry-run по умолчанию у установщиков, идемпотентность, бэкапы перед перезаписью.
- Тесты не трогают `~/.claude/`: цели переопределяются переменными окружения (`docs/TECHNICAL.md`, §13).
- Не выдумывай поля frontmatter: команда — `description`, `argument-hint`, `allowed-tools`,
  `disable-model-invocation`, `effort`; агент — `name`, `description`, `tools`, `disallowedTools`, `model`, `effort`,
  `maxTurns`, `skills`; скил — `name`, `description`, `paths`.
- В `templates/settings*.json.template` не добавлять `Bash(sed *)` и `Bash(cat *)` в allow.
- Абсолютных путей к самому репозиторию не писать: только `~/.claude/my-claude-config/…` (symlink ставит
  установщик). Каталоги машины (work, personal, конвенция, ревью) — из `workspace.conf` и `~/.claude/workspace.md`.

## Язык

Чат — русский, простыми словами; комментарии, коммиты, документация — русский; идентификаторы, имена
файлов и команд — английский. Без ИИ-слопа и эмодзи (правило 07).

## Git

Личный проект: коммит `тип(scope): описание` (feat, fix, docs, refactor, test, chore, build, ci, perf),
по-русски, ≤ 72 символа, без трейлеров. Push и merge — пользователь. Правки живут через symlink сразу,
поэтому крупные переделки — в worktree на ветке.

## Чего не трогать без явного запроса

- `~/.claude/` напрямую — только через `scripts/setup-global.sh` и `scripts/install-hooks.sh`.
- Управляемый блок `BEGIN/END my-claude-config (managed)` в любом `CLAUDE.md`.
- `skills/java-service-convention/references/sonar-rules.md` — генерируется скриптом из плагина команды.
- `docs/projects/` — артефакты проектирования; меняются через `/design`.
- `workspace.conf` — каталоги этой машины, в git не идёт; пример — `workspace.conf.example`.

## Контрольные точки

- 2026-10-11: `/reflect` — 0 вызовов → удалить.
- 2026-10-17: потолки `maxTurns` — пересчитать по логам (`docs/TECHNICAL.md`, §4).
- 2026-11-15: месячный аудит (`scripts/audit/`, `/insights`): мёртвые команды и агенты, rule 08,
  блокировки новых хуков, `[!]` и `[#]` в планах, итерации ревью, замечания критика, вопросы по Sonar.
  План перестройки `docs/refactor-2026-09/plan.html` после этой точки удалить.
