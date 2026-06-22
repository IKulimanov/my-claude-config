---
description: Analyze a fresh project, detect stack, ask targeted questions, and generate a tailored CLAUDE.md. Use in a new repo before any real work.
argument-hint: [optional: --force to overwrite existing CLAUDE.md]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
---

# /onboard — Project Bootstrap

Generates a tailored `CLAUDE.md` for the current project. Detects stack, work-vs-personal, asks the user about things that cannot be inferred from code, picks the right template, fills it in.

## When to Use

- First time opening Claude in a new repo.
- Returning to a side-project after months — refresh the `CLAUDE.md`.
- Inherited a repo with no `CLAUDE.md`.

## Workflow

### Step 1 — Check for existing CLAUDE.md

```bash
ls CLAUDE.md 2>/dev/null
```

- If exists and `--force` not passed → tell the user it exists, show the date, ask if they want to regenerate (use `AskUserQuestion` with options Overwrite/Append-changes/Cancel). Default: cancel.
- If `--force` → backup as `CLAUDE.md.bak.<timestamp>` before overwrite.

### Step 2 — Detect project type (work vs personal)

```bash
pwd
```

- If path starts with `/Users/ivankulimanov/dev/work/` → **work project**. Team convention applies. Use the work-tuned template.
- Otherwise → **personal project**. Use simpler template, no team-convention reference.

### Step 3 — Detect stack

Check files in this order; first match wins primary stack, but record secondary stacks too:

| File | Stack |
|---|---|
| `pom.xml` or `build.gradle(.kts)` | java-service |
| `go.mod` | go-service |
| `package.json` with `"vue"` in dependencies | vue-app |
| `package.json` without vue (or just dist/static) | web-app |
| Only `Dockerfile` / `docker-compose.yml` and no source | docker-service |

Inspect manifests to extract:
- **Java:** Spring Boot version (`<spring-boot.version>` or parent), Maven vs Gradle, JPA/Kafka/Security modules from dependencies.
- **Go:** Go version (`go 1.X` line), HTTP framework (gin/fiber/echo or stdlib), main packages.
- **Vue:** Vue version, Pinia/Router/TypeScript presence, Vite vs Vue CLI.
- **Docker:** base images, compose services.

Detect runtime commands:
- Java: `mvn test` / `gradle test`, `mvn verify`, `mvn package`.
- Go: `go test ./...`, `go build ./...`.
- Vue: parse `package.json` scripts → `npm test`, `npm run dev`, `npm run build`.
- Detect linters: `golangci-lint`, `eslint`, `checkstyle`, `ruff`.

Detect entry points:
- Java: `@SpringBootApplication`-annotated class.
- Go: `package main` with `func main()`.
- Vue: `src/main.ts` or `src/main.js`.

Detect databases/messaging via dependencies:
- Java: look for `spring-boot-starter-data-jpa`, `spring-kafka`, drivers (`ojdbc`, `postgresql`, `clickhouse-jdbc`).
- Go: `pgx`, `sqlx`, `kafka-go`, `redis`.

### Step 4 — Pick template

Map detected stack → template in `templates/`:

| Stack | Template |
|---|---|
| java-service | `templates/CLAUDE.java-service.md.template` |
| go-service | `templates/CLAUDE.go-service.md.template` |
| vue-app | `templates/CLAUDE.vue-app.md.template` |
| web-app | `templates/CLAUDE.web-app.md.template` |
| docker-service | `templates/CLAUDE.docker-service.md.template` |

If detection was ambiguous (multiple manifests like `pom.xml` + `package.json` for a Java service with frontend), ask via `AskUserQuestion`.

### Step 5 — Ask targeted questions

Use `AskUserQuestion` for things that cannot be detected from code. Ask in a single batch (1 round of questions, not back-and-forth). Pick a relevant subset based on stack and work/personal:

**Universal:**
1. Что делает сервис (1 предложение)?
2. Главные upstream системы (что вызывает этот сервис)?
3. Главные downstream системы (кого вызывает этот сервис)?

**Work-only (skip for personal):**
4. Текущая бизнес-цель / основная фича в работе?
5. Есть ли локальные исключения из командной конвенции (что отличается от `/Users/ivankulimanov/dev/work/java/convention-java/`)?
6. Какие папки / файлы НЕЛЬЗЯ трогать без явного запроса?

**Stack-specific:**
- Java: какие БД реально используются (Oracle / PostgreSQL / ClickHouse) и для каких задач (OLTP / OLAP)?
- Java: какие Kafka-топики consume/produce?
- Go: какой HTTP-фреймворк (если не задетектил)?
- Vue: target browsers, есть ли SSR/static export?

Не задавай больше 5-6 вопросов за раз. Если что-то можно вывести из кода — выводи, не спрашивай.

### Step 6 — Fill template

1. Прочитай выбранный template.
2. Подставь:
   - `{{PROJECT_NAME}}` → `basename $(pwd)`
   - `{{DATE}}` → `date +%Y-%m-%d`
3. Заполни секции на основе детекции + ответов пользователя. То, что не известно — оставь `[TBD]` с короткой пометкой что заполнить.
4. Для work-проектов добавь блок:
   ```markdown
   ## Team Convention Source
   Canonical: `/Users/ivankulimanov/dev/work/java/convention-java/docs/`
   When in doubt, READ canonical directly. Skill `java-service-convention` will redirect.
   ```
5. Запиши в `CLAUDE.md`.

### Step 7 — Report

Выведи короткий отчёт:

```markdown
## /onboard complete

**Stack detected:** <stack> (<sub-details>)
**Project type:** work | personal
**Template used:** <template-file>

**Filled automatically:**
- <field>: <value>
- ...

**Pre-filled from your answers:**
- <field>: <value>
- ...

**Still TBD (fill manually):**
- <field>: <reason>
- ...

**Next steps:**
- Review `CLAUDE.md` — adjust any TBD or wrong inferences.
- For work Java projects: load `java-service-convention` skill or run `/feature` — canonical convention will be read.
- For new feature: `/feature <description>` follows TDD-first flow.
```

## Notes

- **Не задавай вопросов о том что можешь сам найти в коде.** Если в `pom.xml` есть `spring-kafka` — Kafka используется, спрашивать не надо.
- **Не пиши boilerplate** который не относится к этому проекту. Если нет Kafka — не упоминай Kafka в CLAUDE.md.
- **Не выдумывай.** Если не уверен — пиши `[TBD]`, а не догадывайся.
- **Уважай существующий `CLAUDE.md`** — без `--force` не перезаписывай.
