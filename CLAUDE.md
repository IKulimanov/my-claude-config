# CLAUDE.md — my-claude-config

> Сгенерирован `/onboard` 2026-06-23. Это **мета-репозиторий**: личная конфигурация Claude Code,
> а не сервис. Здесь нет рантайма, БД, API — есть markdown-инструкции и bash-скрипты, которые
> разворачиваются в `~/.claude/`.

## Что это

Каркас управления поведением агента. Слои:
- `rules/` — тонкий always-on слой. Только то, что специфично для рабочего процесса автора (Jira ID,
  staging-flow, Vault, TDD, язык). Чем меньше — тем лучше.
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

Personal (вне `~/dev/work/`). Командная Java-конвенция здесь не применяется к самому репо, но
описывается внутри `skills/` и `rules/` для использования в рабочих проектах.

## Развёртывание

Всё ставится в `~/.claude/` через `scripts/setup-global.sh` (symlink по умолчанию):

```bash
scripts/setup-global.sh status            # что стоит сейчас vs что встанет
scripts/setup-global.sh install           # dry-run, показывает план
scripts/setup-global.sh install --apply   # реально применить (с бэкапом)
scripts/setup-global.sh uninstall --apply # откатить
```

- Компоненты: `skills,agents,commands,hooks,claude-md,output-styles`.
- `claude-md` генерирует `~/.claude/CLAUDE.md` с `@import` каждого `rules/*.md` между маркерами
  `BEGIN/END my-claude-config (managed)`. **Не редактируй этот блок руками** — он перегенерируется.
  Менять правила нужно в `rules/*.md`, затем `install --apply`.
- Хуки ставит `scripts/install-hooks.sh --write` (мержит в `~/.claude/settings.json` с бэкапом).
- `scripts/analyze-usage.sh` — быстрый отчёт по tools/agents/skills/токенам из `~/.claude/logs/*.jsonl`.
  ВАЖНО: строки `stops.jsonl` кумулятивны в рамках сессии — токены считаются дельтами, не суммой строк.
- `scripts/audit/` — месячный аудит (extract → report_phase1 → build_report): классификация промтов, итерации,
  skills, baseline rule 08. Результаты и протокол — `docs/audit-2026-08/`. Запускать раз в месяц, 2 команды.
- Недельная аналитика (`analytics/`): `scripts/collect-weekly.sh` (снапшоты Сб–Пт UTC, бэкфилл),
  `scripts/render-dashboard.sh` (автономный дашборд), `scripts/run-weekly-review.sh`
  (сбор → headless `claude -p` → дашборд → pathspec-коммит только `analytics/`),
  `scripts/install-weekly-analytics.sh` (launchd, Сб 09:00 + страховка Вс/Пн). Общая
  jq-логика — `scripts/lib/usage-lib.sh`. Детали: `analytics/README.md`.
- Требуется `jq`.

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
- `digest-routine.md` — осиротевший файл, не подключён; решение по нему отложено (не интегрировать без запроса).

## Текущий фокус / TBD

На 2026-08-16 (после аудита `docs/audit-2026-08/`):
- принцип: конфиг меняется только по данным месячного аудита (`scripts/audit/`), не по каталогу идей;
  лимит — не больше 7 изменений за раз, удалять больше, чем добавлять;
- сделано: rule 08 (гипотеза до ответа), rule 06 (случаи тестов — пользователь, код — Claude), анти-слоп в
  rule 07, `/adr`, `/jira` под командный формат, `/reflect` под реальный поток, `/review-mr` без шума;
  удалены 5 мёртвых команд, `prompt-auditor`, meta-skills, мёртвые helpers;
- открыто (решает пользователь, файлы не в git): недельный пайплайн `analytics/` + `collect-weekly/run-weekly-review/
  install-weekly-analytics/render-dashboard` (остановлен на W28, launchd не применён) — удалить или оставить;
  `digest-routine.md`; `docs/AI_USAGE_AUDIT_2026-07.md` (заменён августовским);
- НЕ в работе (осознанно): Jira MCP, skill-creator, plugin packaging — тюнинг инструментов без запроса из данных.
