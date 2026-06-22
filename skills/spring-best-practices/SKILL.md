---
name: spring-best-practices
description: Use for advanced Spring Boot development. Covers bean lifecycle, @ConfigurationProperties, Spring Security patterns, caching, async/scheduling, Spring Data best practices, global error handling, and API design beyond team conventions.
---

# Spring Best Practices

Use this skill for Spring Boot feature work where correct framework usage and production readiness matter — not just naming and structure, but how Spring itself should be used.

## When To Use

- Spring Security setup or changes (filter chains, JWT, method security)
- Caching with `@Cacheable` / Caffeine / Redis
- Async processing with `@Async` or `CompletableFuture`
- `@Scheduled` tasks
- Complex configuration with `@ConfigurationProperties`
- API error handling (`ProblemDetail`, global exception handlers)
- Spring Data query optimization and projections
- Actuator, health checks, Micrometer setup
- Multi-module or conditional bean configuration

## Workflow

1. Read the local `CLAUDE.md` and identify the Spring Boot version and active modules.
2. Load only the reference file relevant to the task:
   - `references/spring-config.md` — configuration, bean lifecycle, profiles, conditional beans
   - `references/spring-security.md` — security filter chains, JWT, CORS, CSRF, method security
   - `references/spring-observability.md` — actuator, Micrometer metrics, health indicators, tracing
3. If JPA is also involved, load `jpa-db-review` skill.
4. If tests are involved, load `testing` skill.

## Guardrails

- Prefer `@ConfigurationProperties` over scattered `@Value` for any config with 2+ related fields.
- Never store mutable state in Spring beans — they are singletons.
- Do not use field injection (`@Autowired` on fields) in production beans.
- `@Transactional` on a method called from within the same class bypasses the proxy — this is a silent bug.
- `@Async` methods called from the same class do not execute asynchronously — document or restructure.
- For REST APIs, make sessions stateless explicitly in the security config.
- Never disable CSRF without a clear security justification.
- Always set explicit `cacheNames` and `key` on `@Cacheable`; never rely on defaults in shared caches.
- Distinguish `fixedDelay` (gap after completion) vs `fixedRate` (gap from start) in `@Scheduled`.
- Use `@ConditionalOnProperty` to make optional features toggleable without code changes.
