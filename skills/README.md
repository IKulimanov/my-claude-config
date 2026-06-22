# Skills

Профильный набор скилов. Грузится по `description` (авто) или вручную (`/skill-name`).
Правило загрузки: бери минимум, нужный под задачу. Если задача про БД или messaging — не
полагайся на общий Java-скил в одиночку.

## Core / meta

- `agent-design` — проектирование и ревью агентов, границ инструментов, gate'ов.
- `prompt-audit` — аудит промптов, команд и слоёв конфига.
- `repo-onboarding` — быстрая карта незнакомого репозитория.

## Java / Spring

- `java-service-convention` — конвенция Maven + Spring сервисов. Для рабочих проектов
  перенаправляет на каноническую конвенцию `~/dev/work/java/convention-java/docs/`.
- `spring-best-practices` — Security, кэш, async/scheduling, `@ConfigurationProperties`,
  ProblemDetail, Actuator/Micrometer, Spring Data.
- `java-patterns` — SOLID, GOF, functional Java, рефакторинг к чистым абстракциям.
- `testing` — JUnit 5, Mockito, AssertJ, `@WebMvcTest`/`@DataJpaTest`, Testcontainers.
- `jpa-db-review` — JPA/Hibernate, SQL, индексы, схема, workload (Oracle/PostgreSQL/ClickHouse).
- `integration-patterns` — Kafka, REST-клиенты, секреты, correlation ID, логирование интеграций.
- `git-convention` — branch naming, commit messages, staging-flow.

## Go

- `go-best-practices` — основной Go-скил: структура проекта, error handling, concurrency,
  интерфейсы, тесты, производительность (production и review).
- `go-service` — лёгкий профиль для домашних Go-сервисов (быстрый старт).

## Frontend

- `vue-frontend` — Vue 3 + Vite: компоненты, Composition API, Pinia, Router, Vitest, TypeScript.
- `web-app` — server-rendered / lightweight web (Go html/template, htmx, Alpine, vanilla JS).
  НЕ для Vue/SPA.

## DevOps

- `docker` — Dockerfile, Docker Compose, локальное dev-окружение, оптимизация образов.
- `gitlab-ci` — `.gitlab-ci.yml`: stages, caching, artifacts, environments, secrets, DinD.
- `kubernetes` — Deployment, Service, ConfigMap, Ingress, probes, resource limits, HPA, rollout.
- `helm` — chart structure, values, templates, hooks, multi-env overrides.
- `terraform` — module structure, state, providers, variables, CI integration.

## Loading Rule

Грузи минимально необходимый набор. Если задача затрагивает несколько слоёв (API + DB + Kafka) —
подключай несколько узких скилов, а не один «всеобъемлющий».
