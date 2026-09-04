# CLAUDE.md — my-claude-config

> Сгенерирован `/onboard` 2026-06-23. Это **мета-репозиторий**: личная конфигурация Claude Code,
> а не сервис. Здесь нет рантайма, БД, API — есть markdown-инструкции и bash-скрипты, которые
> разворачиваются в `~/.claude/`.

## Что это

Каркас управления поведением агента. Слои:
- `rules/` — тонкий always-on слой. Только то, что специфично для рабочего процесса автора (Jira ID,
  staging-flow, Vault, TDD, язык, профили work/personal). Чем меньше — тем лучше.
- `commands/` — повторяемые сценарии (slash-команды).
- `agents/` — субагенты (reviewers, test-writers, migration-reviewer).
- `skills/` — глубокие стек- и доменные знания. Грузятся по соответствию `description`, не «на всякий случай».
- `templates/` — шаблоны `CLAUDE.md` и `settings.json` под профили (java/go/vue/web/docker).
- `hooks/` — block-* (безопасность) и log-* (аналитика) скрипты.
- `output-styles/` — `personal.md` (стиль вывода главного агента).
- `scripts/` — установка и аналитика.
- `docs/` — расширенная документация (ARCHITECTURE, WORKFLOW, HOOKS_GUIDE, ROADMAP и т.д.).

Базовый принцип: always-on слой маленький, стек-специфика в `skills/`, проектные ограничения — в
локальном `CLAUDE.md` конкретного репозитория.

## Тип проекта

Personal (профиль personal, см. `rules/09`). Командная Java-конвенция здесь не применяется к самому репо, но
описывается внутри `skills/` и `rules/` для использования в рабочих проектах.

## Развёртывание

Всё ставится в `~/.claude/` через `scripts/setup-global.sh` (symlink по умолчанию):

```bash
scripts/setup-global.sh status            # что стоит сейчас vs что встанет
scripts/setup-global.sh install           # dry-run, показывает план
scripts/setup-global.sh install --apply   # реально применить (с бэкапом)
scripts/setup-global.sh uninstall --apply # откатить
```

- Компоненты: `skills,agents,commands,hooks,claude-md,output-styles,statusline,config,workspace`.
- `claude-md` генерирует `~/.claude/CLAUDE.md` с `@import` каждого `rules/*.md` и `workspace.md`
  между маркерами `BEGIN/END my-claude-config (managed)`. **Не редактируй этот блок руками** — он
  перегенерируется. Менять правила нужно в `rules/*.md`, затем `install --apply`.
- `config` — symlink репозитория в `~/.claude/my-claude-config`. Через этот путь команды и правила
  ссылаются на `docs/shared/`, `scripts/helpers/` и references скилов. **Внутри репозитория не писать
  абсолютные пути к самому репозиторию** — только `~/.claude/my-claude-config/...`.
- `workspace` — читает `workspace.conf` (машинно-зависимый, в `.gitignore`; создаётся из
  `workspace.conf.example`), создаёт каталоги work/personal и генерирует `~/.claude/workspace.md`
  с путями. Профили work/personal описаны в `rules/09`. **Путь к рабочему каталогу нигде не зашивать** —
  он берётся из `workspace.md`, а тип проекта можно перекрыть строкой `Тип проекта:` в локальном `CLAUDE.md`.
- Хуки и базовые настройки (`permissions`, `cleanupPeriodDays`) ставит `scripts/install-hooks.sh --write`:
  `hooks` и `cleanupPeriodDays` перезаписываются, `permissions` объединяются с уже существующими.
- `scripts/analyze-usage.sh` — быстрый отчёт по tools/agents/skills/токенам из `~/.claude/logs/*.jsonl`.
  ВАЖНО: строки `stops.jsonl` кумулятивны в рамках сессии — токены считаются дельтами, не суммой строк.
- `scripts/audit/` — месячный аудит (extract → report_phase1 → build_report): классификация промтов, итерации,
  skills, baseline rule 08. Результаты и протокол — `docs/audit-2026-08/`. Запускать раз в месяц, 2 команды.
- Требуется `jq`. Для хуков защиты — `trufflehog` (без него `block-push-secrets.sh` пишет
  в `blocks.jsonl` запись `kind: "scan-skipped"`, чтобы отсутствие защиты было видно).

## Конвенции авторинга

- **Не выдумывай поля frontmatter.** Канон:
  - command: `argument-hint`, `allowed-tools` (+ описание). Нет `effort`, `context`.
  - agent: `name`, `description`, `tools`, `model`, `skills`. Поле `skills:` ОФИЦИАЛЬНО поддерживается
    (не удалять — старая заметка «skills не существует» устарела). Список нужных skills — во frontmatter
    и/или в теле промпта. Нет `maxTurns`.
- skill грузится по `description`. Узкие skills лучше одного «всеобъемлющего». Не дублируй системный
  промпт Claude Code в `rules/`.
- `templates/settings*.json.template`: в allowlist НЕ добавлять `Bash(sed *)` / `Bash(cat *)`
  (`sed` — обход Edit/Write; `cat` запрещён системным промптом).
- Границы дублирующихся ролей явные: web-* — NOT for Vue (используй vue-frontend / vue-reviewer).

## Bash-скрипты

- `set -euo pipefail`, dry-run по умолчанию, флаг `--apply` для реальных изменений, бэкапы перед
  перезаписью, идемпотентность, поддержка `uninstall`.
- Скрипты затрагивают `~/.claude/` — это домашняя конфигурация. Любой `--apply` меняет глобальное
  окружение пользователя: запускать осознанно, не из чата без явного запроса.

## Язык (rule 07)

- Чат: русский, простыми словами (см. `rules/07`, `output-styles/personal.md`).
- Комментарии в коде, commit-сообщения, документация (README, docs, этот файл): русский.
- Идентификаторы, имена веток, ключи конфигов, имена команд/скиллов/агентов: английский.

## Чего не трогать без явного запроса

- `~/.claude/` напрямую (через скрипты, не руками) — это применённая глобальная конфигурация.
- Управляемый блок `BEGIN/END my-claude-config (managed)` в любом `CLAUDE.md`.
- `.claude/` репозитория — в `.gitignore`, локальные переопределения.
- `workspace.conf` — машинно-зависимый, в `.gitignore`. Правится руками, читается установщиком.

## Текущий фокус / TBD

Принцип (с аудита 2026-08): конфиг меняется только по данным месячного аудита (`scripts/audit/`),
не по каталогу идей; лимит — не больше 7 изменений за раз, удалять больше, чем добавлять.

На 2026-09-04 (переезд на новую машину + аудит конфига):
- сделано в августе: rule 08 (гипотеза до ответа), rule 06 (случаи тестов — пользователь, код — Claude),
  анти-слоп в rule 07, `/adr`, `/jira` под командный формат, `/reflect` под реальный поток;
  удалены 5 мёртвых команд, `prompt-auditor`, meta-skills, мёртвые helpers;
- сделано в сентябре: конфиг отвязан от прежней машины (компоненты `config` + `workspace`,
  `~/.claude/my-claude-config`, `workspace.conf`); rule 09 (профили work/personal); `block-secrets.sh`
  переписан после трёх ложных срабатываний; логирующие хуки асинхронные, журналы ротируются;
  `permissions` и `cleanupPeriodDays` ставятся установщиком; удалён недельный пайплайн `analytics/`,
  `digest-routine.md`, июльский аудит, skill `go-service`; Context7 MCP;
- открыто: перевод внутренних промтов команд на русский (сейчас переведены только видимые пользователю
  части); проверить на живой сессии, работает ли `paths:` в skills; разделить `sonar-rules.md`
  на чек-лист и детали;
- НЕ в работе (осознанно): Jira MCP, SonarQube MCP (до токена), skill-creator, plugin packaging.
