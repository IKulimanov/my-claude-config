---
name: java-service-convention
description: Use for Maven-based Spring Boot services. In the work profile the canonical team convention (path in ~/.claude/workspace.md) is the AUTHORITATIVE source — read it directly, do not rely on the summary in this skill. In the personal profile the team convention does not apply; the guardrails and references here are best-practices.
paths: "**/*.java"
---

# Java Service Convention

## Шаг 0 — Определить профиль проекта (КРИТИЧНО)

Профиль определяется по rule «Профили проектов»: строка `Тип проекта:` в локальном `CLAUDE.md`,
иначе каталог из `~/.claude/workspace.md`.

- **Профиль work** → авторитетный источник только один: каноническая командная конвенция, путь к ней
  в `~/.claude/workspace.md` (ключ «Каноническая Java-конвенция»). Пересказы в `references/`
  (`java-style.md`, `spring-service.md`, `data-access.md`, `db-design.md`, `kafka.md`) сделаны по более
  ранней версии конвенции — как источник истины для work их не использовать.
  **Исключение:** `references/sonar-rules.md` — сгенерированное зеркало правил Sonar из CI, остаётся
  надёжным чек-листом для локального предчека (шаг 1).
  Если канон не задан в `~/.claude/workspace.md` — работать по `sonar-rules.md` и сказать об этом
  пользователю одной строкой.
- **Профиль personal** → командная конвенция НЕ применяется. Пересказы в `references/` и guardrails
  ниже работают как обычные best-practices: бери их как советы, не как обязательные правила.
  Не требуй Jira ID, staging-flow и коды Sonar.

## Шаг 1 — Прочитать каноническую конвенцию (только профиль work)

В профиле work, до написания нетривиального Java-кода:

1. Прочитать индекс: `<канон>/index.md`, где `<канон>` — путь из `~/.claude/workspace.md`
2. Read the specific section(s) for your task — examples:
   - Git / branches / commits → `docs/001_git.md`
   - Project dependencies → `docs/002_project_deps.md`
   - Language style (naming, methods, exceptions, comments) → `docs/003_lang/*.md`
   - Frameworks (Lombok etc.) → `docs/004_frameworks_libs/*.md`
   - Spring ecosystem (controllers, DAO, schedulers, REST, secrets, logging) → `docs/005_spring_ecosystem/*.md`
   - Kafka → `docs/006_common_software/01_kafka.md`
   - Databases (Oracle/PG/CH) → `docs/007_databases/*.md`
   - IDE setup → `docs/009_ide.md`

**Compact Sonar-aligned checklist (use this while writing AND checking):**
`references/sonar-rules.md` — a generated digest of the team's actual SonarQube rules
(`convention-sonar-rules-plugin`), with rule codes (LANG-/SPR-/DB-), one-line statements, and
compliant/non-compliant examples. It matches what **CI Sonar** enforces (`mvn verify sonar:sonar`),
so checking against these codes predicts the CI quality gate. Regenerate after rule changes:
`scripts/gen-convention-checklist.sh`. This is INTERNAL — do not publish.

When canonical conflicts with the summary in `references/` of this skill — **canonical wins, always**.
`sonar-rules.md` is derived directly from the enforced rules and is safe to rely on; the other
`references/*.md` are historical summaries (see below).

## Step 1b — Scope: convention applies to code you touch (v1.2.0, work projects)

Convention `index.md` → «Применение конвенции при внесении изменений в код»:

- If you modify an existing method, **that method must be brought into line with the convention in the
  same change**. The last person to touch it owns its compliance.
- Cascading counts: changes introduced *by* the alignment are themselves subject to the convention.
- Untouched code stays untouched — do not reformat whole files or unrelated methods.
- If alignment would require significant work (changing an interface contract, edits across several
  classes), do **not** do it silently — tell the user it needs sign-off from the team lead.

## Step 2 — Apply

- Read the local project `CLAUDE.md` for service boundaries and local exceptions.
- For task-specific reading: load `integration-patterns` if touching Kafka/REST clients; `git-convention` if branching/committing.
- Plan first when the change affects API shape, DB schema, or external integrations.

## Quick Guardrails

These are valid for both work and personal projects. They are NOT a substitute for the canonical document — they exist so Claude has a safety net before re-reading canonical.

- Constructor injection via `@RequiredArgsConstructor`.
- Keep controllers thin — parse input, call service, return output.
- Do not leak JPA entities outside the data-owning layer — use models/DTOs.
- Prefer domain exceptions over generic runtime exceptions.
- Do not log secrets, OTP, passwords, keys — mask to first/last char.
- Organize packages by domain, not by technical type.
- Nullability (LANG-223): JSpecify only for static analysis — `@NullMarked` at package level,
  `@Nullable` for exceptions, `@NonNull` where genuinely needed. `@NotNull` **only** from
  `jakarta.validation.constraints`, and only at a Bean Validation boundary — never `lombok.NonNull`
  or `org.jetbrains.annotations.NotNull`.
- Field access (LANG-115): read class fields through `this`. Exception — DI collaborators
  (`@Autowired`/`@Inject`/`@Resource`/`@Named`, constructor-injected collaborators, `@RequiredArgsConstructor`
  beans). Plain value fields (`Integer`, `String`, `BigDecimal`, …) still need `this`, even when they
  come through the constructor.
- Use `EnumSet`/`EnumMap` for enum collections.

## What lives where

- `references/sonar-rules.md` — **generated Sonar-aligned checklist** (codes + examples), matches CI Sonar. Regenerate with `scripts/gen-convention-checklist.sh`. INTERNAL — do not publish. This is the concrete rule set to check against locally.
- `references/java-style.md`, `references/spring-service.md`, `references/data-access.md`, `references/db-design.md`, `references/kafka.md` — пересказы по более ранней версии конвенции. Для профиля **personal** это обычные best-practices, ими можно пользоваться напрямую. Для профиля **work** — только для быстрой справки, источник истины там канон.
- Канон командной конвенции — путь в `~/.claude/workspace.md`. Авторитетный источник для профиля work.
