---
name: integration-patterns
description: Use for Kafka, REST clients, secret handling, logging, correlation IDs, and service-to-service integration in Java services. Triggers on @KafkaListener/KafkaTemplate, producer/consumer, retry/DLQ/idempotency, Feign/RestClient/WebClient, timeouts, correlation-id, Vault secrets, structured logging.
---

# Integration Patterns

Use this skill when a task touches outbound REST, Kafka, secrets, or cross-service observability.

## Workflow

1. Read the local project `CLAUDE.md`.
2. Read `references/service-integrations.md` for REST, secrets, and logging patterns.
3. For Kafka-specific work in a work project, read `006_common_software/01_kafka.md` in the canonical convention directory (line «Каноническая Java-конвенция» in `~/.claude/workspace.md`; not set → skip) for consumer/producer conventions.
4. Check the change for observability, secret handling, retry behavior, and backward compatibility.
5. If the change includes DB-backed outbox or persistence, also load `jpa-db-review`.

## Guardrails

- Do not log secrets, OTPs, passwords, private keys, or full auth factors.
- Preserve or generate correlation IDs and propagate them downstream.
- Prefer existing starters and shared libraries when the project ecosystem standardizes them:
  - Kafka: `kafka-events-handling-starter`
  - REST: `communication-rest-client` starter
  - Secrets: `secrets-vault-provider`
- Review both success-path metrics and failure-path behavior.
- Classify errors: retryable (network, timeout) vs non-retryable (validation, deserialization).
- Use dead-letter topics (DLT) for messages that fail after retries.
