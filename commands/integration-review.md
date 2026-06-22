---
description: Review Kafka and REST integrations for correctness, observability, error handling, and secret management.
argument-hint: [optional integration scope]
allowed-tools: Read, Grep, Glob, Bash
---

# Integration Review

Use for changes involving Kafka, REST clients, correlation IDs, or Vault-backed secrets.

## Required Context

Load `skills/integration-patterns` and `skills/java-service-convention/references/kafka.md`.

## Review Checklist

### Kafka
- [ ] Consumer metrics via `MicrometerConsumerListener`
- [ ] Producer metrics via `MicrometerProducerListener` (use `kafka.producer.**`)
- [ ] Idempotent processing (messages may be delivered more than once)
- [ ] Poison pill handling (log + skip undeserializable, don't block partition)
- [ ] Error classification: retryable vs non-retryable
- [ ] Dead-letter topic (DLT) for failed messages
- [ ] Meaningful consumer group IDs
- [ ] Consumer lag monitoring
- [ ] Using team's `kafka-events-handling-starter` when available

### REST Clients
- [ ] Using team's `communication-rest-client` starter when available
- [ ] Custom Prometheus tags: `connector.code`, `connector.target`, `metric.version`
- [ ] Path variables via `Map`, not string concatenation
- [ ] Important calls logged to external storage (`logging-kafka` starter)
- [ ] Timeout and retry configuration
- [ ] Circuit breaker for critical dependencies

### Secrets
- [ ] Passwords, tokens, certs, keys → Vault only
- [ ] URLs, flags, params, topic names → config (NOT Vault)
- [ ] Using `secrets-vault-provider` for REST secrets

### Observability
- [ ] Correlation ID propagation (inbound → outbound)
- [ ] Structured logging (JSON in prod)
- [ ] Entity identifier in log messages or MDC
- [ ] No double-logging on rethrow

## Output Format

```text
# Integration Review

## Findings
- <severity> — <issue> — <production impact>

## Observability Gaps
- <missing metrics or correlation IDs>

## Security
- <secret or logging risks>

## Follow-up
- <tests or config changes needed>
```
