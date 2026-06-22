# Service Integrations Reference

## Kafka

- Consumers should expose useful metrics.
- Producers should expose topic-aware producer metrics.
- When the team already uses a standard starter for Kafka handling, prefer it over custom glue code.
- Check idempotency, duplicate handling, and failure policy.

## REST Clients

- Prefer the team's shared REST client when the stack supports it.
- When using path variables, keep templated URIs and pass variable maps instead of string-concatenated final URLs.
- Important external interactions may need durable request and response logging outside the service.

## Secrets

- Secrets belong in Vault.
- URLs, feature flags, limits, and topic names are config, not secrets.
- Do not move non-secret config into Vault just because it is externalized.

## Logging And Tracing

- Use one log message format per functional flow.
- Put searchable domain identifiers at the start of logs or into MDC.
- JSON logging is the expected production direction when the project supports it.
- Do not double-log exceptions that will be handled or rethrown upstream.
