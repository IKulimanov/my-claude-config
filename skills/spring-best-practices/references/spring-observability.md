# Spring Observability Reference

## Actuator Setup

Expose endpoints explicitly — never use `include: '*'` in production without a separate security layer.

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus
  endpoint:
    health:
      show-details: when-authorized
  info:
    git:
      mode: full
```

Key endpoints:
- `/actuator/health` — liveness + readiness; Kubernetes probes point here
- `/actuator/prometheus` — Micrometer metrics for Prometheus scraping
- `/actuator/info` — build version, git commit; keep it current

## Health Indicators

Write custom `HealthIndicator` for external dependencies (message broker, third-party API):

```java
@Component
public class PaymentGatewayHealthIndicator implements HealthIndicator {
    @Override
    public Health health() {
        boolean up = gateway.ping();
        return up ? Health.up().build()
                  : Health.down().withDetail("reason", "Gateway unreachable").build();
    }
}
```

Separate liveness (is the JVM alive?) from readiness (can it serve traffic?) if using Kubernetes:
```yaml
management.endpoint.health.group:
  liveness.include: livenessState
  readiness.include: readinessState, db, kafka
```

## Micrometer Metrics

Use `MeterRegistry` for custom metrics; avoid creating meters inside hot paths — register once, record often.

```java
// Counter
Counter.builder("payment.processed")
       .tag("status", "success")
       .register(registry)
       .increment();

// Timer
Timer.builder("payment.duration")
     .publishPercentiles(0.5, 0.95, 0.99)
     .register(registry)
     .record(() -> processPayment(request));
```

Tag cardinality matters: do not use user IDs or request IDs as tag values — it creates unbounded cardinality.

## Distributed Tracing

With Spring Boot 3 + Micrometer Tracing:
- Add `micrometer-tracing-bridge-otel` + exporter (Zipkin or OTLP).
- `TraceId` and `SpanId` are automatically propagated through `RestTemplate`, `WebClient`, and Spring Messaging.
- To propagate in async code: use `Observation` API or pass `TraceContext` explicitly.
- Always include `traceId` in error responses and log correlation.

## Structured Logging

With `logback-spring.xml` or `log4j2-spring.xml`:
- Add Logstash encoder for JSON logs in production.
- Put `traceId`, `spanId`, and domain identifiers into MDC.
- Keep `traceId` in error responses for support engineers.

```java
try (var ignored = tracer.startScopedSpan("processPayment")) {
    MDC.put("paymentId", payment.id().toString());
    // business logic
}
```
