# Spring Service Reference

## General Spring Conventions

- Use latest in-house libraries compatible with the Spring Boot version.
- App must safely run with default config in dev environments.
- Override config via IDE environment variables, not files.
- Extract bean names/qualifiers to constants.
- Name `@PostConstruct` methods as `initialize()`.
- Store durations as `java.time.Duration`, not loose integers with implicit units.

## Dependency Injection

- Prefer constructor injection via `@RequiredArgsConstructor`.
- In `@Configuration` classes, inject dependencies through `@Bean` method parameters, not class fields.
- If bean names or qualifiers are explicit, keep them in constants.
- Never use field injection (`@Autowired` on fields).

## Controllers

- Split controllers by functional responsibility, not by entity.
- Keep controllers thin: parse input → call service → return output.
- Use `@Valid` on POJO request models.
- All failures handled in global or controller-specific `@ExceptionHandler`.
- Don't return `ResponseEntity` for success — use `@ExceptionHandler` for errors. Reserve `ResponseEntity` for special cases (files, custom headers).
- Create custom validators for domain-specific IDs (phone format, INN, etc.).
- Document every method in OpenAPI.
- Use separate `*Api` interface for Swagger documentation (pattern: `<ControllerName>Api`).
- Maximize Swagger auto-extraction from method signatures.

## Security And API Hygiene

- All routes (except Actuator) require authentication.
- Don't use Basic auth (Base64 is easily decoded).
- Log correlation-id/trace-id for distributed tracing.
- Prefer explicit validation for domain identifiers with known formats.
- Carry correlation IDs across inbound and outbound calls.
- Keep OpenAPI descriptions current.

## Schedulers (Jobs)

- All mutable jobs must be disabled by default via `@ConditionalOnProperty`.
- Move cron expression/period to `application.yml`.
- Time values in `@Scheduled` use `Duration` format.
- Implement check for ongoing job execution (prevent overlapping).
- Handle parallel execution on multiple instances (distributed locks or safe logic).

## REST Operations (Outbound)

- Use team's `communication-rest-client` starter (Spring Boot 3.2.5+) when available.
- Add custom Prometheus tags: `connector.code`, `connector.target`, `metric.version`.
- Use `Map` for path variables (not string concatenation).
- Log important external calls to external storage (use `logging-kafka` starter).
- Use `secrets-vault-provider` for REST service secrets.

## Secrets Management

- Secrets: passwords, tokens, certificates, encryption keys → store in Vault.
- NOT secrets: URLs, feature flags, parameters, queue/table names → keep in config.
- Don't store non-secrets in Vault. Don't mix secret and config storage.

## Logging

- Never use `System.out` for application logging — use SLF4J.
- Use parameterized messages, not string concatenation.
- Maintain consistent format per functionality.
- Start log messages with entity identifier (user ID, phone, etc.).
- Use `MDC` (Mapped Diagnostic Context) for structured logging.
- Production: structured JSON logging. Local dev: console format is fine.
- Never log full OTP/password/key — mask all but first/last character (min 5 chars).
- Don't log exception if re-throwing or wrapping with `cause`.

## Actuator

- Control Actuator endpoints explicitly.
- Disable sensitive endpoints: `shutdown`, `env`, `heapdump`, `threaddump`.
- Keep health and metrics endpoints available.

## Project Hygiene

- Remove IDE config files (`.idea/`).
- Remove `HELP.md` and maven-wrapper files.
- README.md must include: project purpose, local build/run instructions, special conventions.
- Run SonarQube analysis before each commit.
