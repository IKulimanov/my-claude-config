---
description: Analyze a fresh project, detect stack, ask targeted questions, and generate a tailored CLAUDE.md. Use in a new repo before any real work.
argument-hint: [optional: --force to overwrite existing CLAUDE.md]
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, AskUserQuestion
effort: medium
---

# /onboard — Project Bootstrap

Генерирует `CLAUDE.md` под текущий проект. Определяет стек и профиль (work или personal), спрашивает
о том, чего не видно в коде, выбирает подходящий шаблон и заполняет его.

## Когда применять

- Первый запуск Claude в новом репозитории.
- Возвращение к своему проекту через несколько месяцев — обновить `CLAUDE.md`.
- Достался репозиторий без `CLAUDE.md`.

## Порядок работы

### Шаг 1 — Проверить, есть ли CLAUDE.md

```bash
ls CLAUDE.md 2>/dev/null
```

- Файл есть и `--force` не передан → скажи пользователю, что файл существует, покажи дату и спроси, генерировать ли заново (через `AskUserQuestion` с вариантами: перезаписать / дописать изменения / отмена). По умолчанию — отмена.
- Передан `--force` → перед перезаписью сделай бэкап `CLAUDE.md.bak.<timestamp>`.

### Шаг 2 — Определить тип проекта (work или personal)

```bash
pwd
```

- Путь под каталогом work из `~/.claude/workspace.md` → профиль **work**. Командная конвенция действует, бери work-шаблон.
- Путь под каталогом personal (или профиль не определился) → профиль **personal**. Простой шаблон, без ссылок на командную конвенцию.
- Подробности профилей — rule «Профили проектов».

### Шаг 3 — Определить стек

Проверяй файлы в этом порядке; первое совпадение даёт основной стек, но второстепенные тоже запиши:

| Файл | Стек |
|---|---|
| `pom.xml` или `build.gradle(.kts)` | java-service |
| `go.mod` | go-service |
| `package.json` с `"vue"` в зависимостях | vue-app |
| `package.json` без vue (или только dist/статика) | web-app |
| Только `Dockerfile` / `docker-compose.yml`, исходников нет | docker-service |

Из манифестов вытащи:
- **Java:** версию Spring Boot (`<spring-boot.version>` или parent), Maven или Gradle, модули JPA/Kafka/Security из зависимостей.
- **Go:** версию Go (строка `go 1.X`), HTTP-фреймворк (gin/fiber/echo или stdlib), основные пакеты.
- **Vue:** версию Vue, наличие Pinia/Router/TypeScript, Vite или Vue CLI.
- **Docker:** базовые образы, сервисы в compose.

Определи команды запуска:
- Java: `mvn test` / `gradle test`, `mvn verify`, `mvn package`.
- Go: `go test ./...`, `go build ./...`.
- Vue: разбери scripts в `package.json` → `npm test`, `npm run dev`, `npm run build`.
- Найди линтеры: `golangci-lint`, `eslint`, `checkstyle`, `ruff`.

Определи точки входа:
- Java: класс с аннотацией `@SpringBootApplication`.
- Go: `package main` с `func main()`.
- Vue: `src/main.ts` или `src/main.js`.

Определи БД и брокеры по зависимостям:
- Java: ищи `spring-boot-starter-data-jpa`, `spring-kafka`, драйверы (`ojdbc`, `postgresql`, `clickhouse-jdbc`).
- Go: `pgx`, `sqlx`, `kafka-go`, `redis`.

### Шаг 4 — Выбрать шаблон

Сопоставь определённый стек с шаблоном в `~/.claude/my-claude-config/templates/`:

| Стек | Шаблон |
|---|---|
| java-service | `~/.claude/my-claude-config/templates/CLAUDE.java-service.md.template` |
| go-service | `~/.claude/my-claude-config/templates/CLAUDE.go-service.md.template` |
| vue-app | `~/.claude/my-claude-config/templates/CLAUDE.vue-app.md.template` |
| web-app | `~/.claude/my-claude-config/templates/CLAUDE.web-app.md.template` |
| docker-service | `~/.claude/my-claude-config/templates/CLAUDE.docker-service.md.template` |

Если детект получился неоднозначным (например, есть и `pom.xml`, и `package.json` — Java-сервис с фронтендом), спроси через `AskUserQuestion`.

### Шаг 5 — Задать точечные вопросы

Через `AskUserQuestion` спрашивай только то, чего не видно в коде. Спрашивай одним пакетом (один раунд вопросов, не переписка). Подбери набор под стек и профиль work/personal:

**Общие:**
1. Что делает сервис (1 предложение)?
2. Главные upstream системы (что вызывает этот сервис)?
3. Главные downstream системы (кого вызывает этот сервис)?

**Только для профиля work (для personal пропустить):**
4. Текущая бизнес-цель / основная фича в работе?
5. Есть ли локальные исключения из командной конвенции (что отличается от канона, путь к нему — в `~/.claude/workspace.md`)?
6. Какие папки / файлы НЕЛЬЗЯ трогать без явного запроса?

**По стеку:**
- Java: какие БД реально используются (Oracle / PostgreSQL / ClickHouse) и для каких задач (OLTP / OLAP)?
- Java: какие Kafka-топики consume/produce?
- Go: какой HTTP-фреймворк (если не задетектил)?
- Vue: target browsers, есть ли SSR/static export?

Не задавай больше 5-6 вопросов за раз. Если что-то можно вывести из кода — выводи, не спрашивай.

### Шаг 6 — Заполнить шаблон

1. Прочитай выбранный template.
2. Подставь:
   - `{{PROJECT_NAME}}` → `basename $(pwd)`
   - `{{DATE}}` → `date +%Y-%m-%d`
3. Заполни секции на основе детекции + ответов пользователя. То, что не известно — оставь `[TBD]` с короткой пометкой что заполнить.
4. В начало файла добавь строку профиля — она главнее путей и не даст перепутать тип проекта:
   ```markdown
   Тип проекта: work
   ```
   (или `personal`). Для work-проектов добавь ещё блок:
   ```markdown
   ## Источник командной конвенции
   Канон: путь из `~/.claude/workspace.md` (ключ «Каноническая Java-конвенция»).
   Сомневаешься — читай канон напрямую. Скил `java-service-convention` направит.
   ```
5. Запиши в `CLAUDE.md`.

### Шаг 6b — Проектные права (`.claude/settings.local.json`)

Глобальные ограждения (правило 09) закрывают git, `.gitlab-ci.yml`, `.gitlab/`, `helm/`. Проектные добавки
(Dockerfile, манифесты зависимостей) живут в `.claude/settings.local.json` проекта — файл личный, в git не идёт.

1. Возьми `permissions.ask` из шаблона профиля: `~/.claude/my-claude-config/templates/settings.<profile>.json.template`
   (`java-service` → `pom.xml`, `go-service` → `go.mod`, `web-app` → `package.json`, `docker-service` → compose).
2. Если `.claude/settings.local.json` нет — создай с секцией `permissions.ask` из шаблона. Если есть — добавь
   недостающие элементы в `permissions.ask`, остальное не трогай.
3. В `.gitignore` проекта ничего не добавляй: `.claude/settings.local.json` и `.claude/tasks/` игнорируются
   глобальным excludes git, который ставит `setup-global.sh` (компонент `git-excludes`).
4. Спроси пользователя одним вопросом, есть ли в проекте другие папки «не трогать без запроса», и добавь их
   в тот же список (`Edit(<путь>/**)`, `Write(<путь>/**)`).

### Шаг 7 — Отчитаться

Выведи короткий отчёт:

```markdown
## /onboard завершён

**Определён стек:** <стек> (<подробности>)
**Тип проекта:** work | personal
**Использован шаблон:** <файл-шаблона>

**Заполнено автоматически:**
- <поле>: <значение>
- ...

**Заполнено из твоих ответов:**
- <поле>: <значение>
- ...

**Осталось TBD (заполнить вручную):**
- <поле>: <почему>
- ...

**Что дальше:**
- Просмотри `CLAUDE.md` — поправь TBD и неверные догадки.
- Для рабочих Java-проектов: загрузи скил `java-service-convention` или запусти `/feature` — каноническая конвенция будет прочитана.
- Для новой фичи: `/feature <описание>` идёт по TDD-first потоку.
```

## Заметки

- **Не задавай вопросов о том что можешь сам найти в коде.** Если в `pom.xml` есть `spring-kafka` — Kafka используется, спрашивать не надо.
- **Не пиши boilerplate** который не относится к этому проекту. Если нет Kafka — не упоминай Kafka в CLAUDE.md.
- **Не выдумывай.** Если не уверен — пиши `[TBD]`, а не догадывайся.
- **Уважай существующий `CLAUDE.md`** — без `--force` не перезаписывай.
