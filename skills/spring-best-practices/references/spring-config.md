# Spring Configuration Reference

## @ConfigurationProperties vs @Value

Prefer `@ConfigurationProperties` when:
- Config has 2+ related fields (group them into a typed class)
- You need validation (`@Validated` + JSR-303 on the class)
- You want relaxed binding (kebab-case in YAML -> camelCase in Java)

Use `@Value` only for a single independent property or SpEL expression.

```java
// Good: grouped config
@ConfigurationProperties(prefix = "payment.gateway")
@Validated
public record PaymentGatewayConfig(
    @NotBlank String baseUrl,
    Duration timeout,
    int maxRetries
) {}

// Bad: scattered @Value
@Value("${payment.gateway.base-url}") String baseUrl;
@Value("${payment.gateway.timeout}") Duration timeout;
```

## Bean Lifecycle

- `@PostConstruct` - runs after dependency injection; use for initialization that needs injected state.
- `@PreDestroy` - runs before context shutdown; use for cleanup (close connections, cancel tasks).
- `InitializingBean` / `DisposableBean` - Spring-specific interfaces; prefer `@PostConstruct` / `@PreDestroy` for less coupling.
- `@Bean(initMethod = "...", destroyMethod = "...")` - for third-party classes you cannot annotate.

Do not call overridable methods from `@PostConstruct`.

## Conditional Beans

| Annotation | When to use |
|---|---|
| `@ConditionalOnProperty` | Feature flags, enable/disable integrations |
| `@ConditionalOnMissingBean` | Provide defaults that users can override |
| `@ConditionalOnClass` | Optional dependency on a library |
| `@Profile` | Environment-specific beans (dev/test/prod) |

Avoid `@Profile` for business feature flags - use `@ConditionalOnProperty` instead.

## Profile Management

- Keep environment-specific config in `application-{profile}.yaml`, not in `application.yaml`.
- Do not mix profile-specific values with common values in the same file.
- Test profile (`application-test.yaml`) should override external services with stubs or Testcontainers.
- Never put secrets in `application.yaml` - use environment variables or a secrets manager.

## @Bean Method Injection

In `@Configuration` classes, inject dependencies via `@Bean` method parameters:

```java
// Good
@Bean
public PaymentService paymentService(PaymentGatewayConfig config, HttpClient client) {
    return new PaymentService(config, client);
}

// Avoid: field injection in @Configuration
@Autowired
private PaymentGatewayConfig config;
```

## Scope Management

- Default scope is `singleton` - design beans to be stateless.
- `@RequestScope` or `@SessionScope` creates a proxy; ensure thread-safe access.
- Injecting a narrow-scoped bean (request) into a wide-scoped bean (singleton) requires `@ScopedProxy`.
