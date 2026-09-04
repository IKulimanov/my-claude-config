# Shared: определение стека и загрузка скилов

Переиспользуемый блок для команд `/feature`, `/fix`, `/plan`, `/task`. Единый источник истины —
не дублируй эти таблицы в командах, ссылайся сюда.

## Определить стек

1. Прочитать локальный `CLAUDE.md`.
2. Определить стек:
   - **Java/Spring**: `pom.xml` или `build.gradle` → версия Spring Boot, модули (JPA, Kafka, REST, Security)
   - **Go**: `go.mod` → версия Go, основные пакеты, HTTP-фреймворк
   - **Vue/Vite**: `package.json` с `vue`, `vite.config.ts` → версия Vue, Pinia, Router, TypeScript
   - **Web (прочее)**: `package.json` без Vue, либо статический HTML → бандлер, CSS-фреймворк
3. **Профиль проекта:** по rule «Профили проектов» — строка `Тип проекта:` в локальном `CLAUDE.md`,
   иначе каталог из `~/.claude/workspace.md`. В профиле **work** действует каноническая конвенция:
   для Java загрузить скил `java-service-convention`, он направит на канон (путь — в `~/.claude/workspace.md`).
   В профиле **personal** командная конвенция не применяется.
4. Переформулировать требование в конкретных технических терминах до планирования.

## Загрузить скилы по тому, что затронуто

### Java/Spring
| Что затронуто | Загрузить |
|---|---|
| Любой Java-код | `java-service-convention` |
| Spring beans, config, Security, Async, Cache | `spring-best-practices` |
| Структура кода, новые абстракции, паттерны | `java-patterns` |
| JPA-сущности, репозитории, SQL, схема | `jpa-db-review` |
| Kafka consumer/producer, REST-клиенты | `integration-patterns` |
| Тесты (всегда) | `testing` |

### Go
| Что затронуто | Загрузить |
|---|---|
| Любой Go-код | `go-best-practices` |
| HTTP-хендлеры, middleware, роутинг | `go-best-practices` + `web-app` (если отдаётся HTML) |
| Конкурентность, горутины | `go-best-practices/references/concurrency.md` |
| Тесты (всегда) | `go-best-practices/references/testing.md` |

### Vue/Vite
| Что затронуто | Загрузить |
|---|---|
| Компоненты, composables | `vue-frontend` |
| Pinia stores | `vue-frontend/references/state-routing.md` |
| Router | `vue-frontend/references/state-routing.md` |
| Тесты (всегда) | `vue-frontend/references/testing-vue.md` |

### Всегда
| Что затронуто | Загрузить |
|---|---|
| Docker, CI, K8s | релевантный DevOps-скил |
| Git-ветки, commit-сообщения | `git-convention` |
