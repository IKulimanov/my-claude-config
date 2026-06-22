# Kafka Integration Reference

## Consumers

- Consumer factory must provide metrics via `MicrometerConsumerListener`.
- Use team's `kafka-events-handling-starter` for standard message processing when available.
  - Features: metrics, multi-cluster support, deduplication, in-flight checks, configurable error handling.
- Implement idempotent processing — messages may be delivered more than once.
- Handle poison pills: log and skip undeserializable messages, don't block the partition.
- Set meaningful consumer group IDs that identify the service and purpose.
- Monitor consumer lag as a key health metric.

## Producers

- Kafka Template provides metrics via `MicrometerProducerListener`.
- Important: use `kafka.producer.**` metrics, not `spring.kafka.template`.
- If using `kafka-events-handling-starter`, use its built-in producer for consistency.
- Set `acks=all` for critical messages. Understand the durability trade-off for `acks=1`.
- Use a meaningful key for partitioning when ordering matters.
- Serialize with a schema (Avro, Protobuf, JSON Schema) when cross-team consumers exist.

## Error Handling

- Classify errors: retryable (network, timeout) vs non-retryable (validation, deserialization).
- Use dead-letter topic (DLT) for messages that fail after retries.
- Log failed messages with enough context to replay or investigate.
- Don't silently swallow exceptions in consumer handlers.

## Topic Conventions

- Topic names should be descriptive: `{domain}.{entity}.{event}` (e.g. `order.payment.completed`).
- Define retention, partitions, and replication factor at topic creation.
- Document topic schemas and ownership.

## Observability

- Expose consumer lag, processing rate, error rate metrics.
- Use correlation IDs in message headers — propagate from inbound requests.
- Log topic, partition, offset on processing failures.
