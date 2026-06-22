# Vendor Notes

## Oracle And PostgreSQL For Service Workloads

- Treat them as transactional stores unless the project says otherwise.
- Set explicit pool names and DB-visible application names.
- Review indexes against real filter and join patterns.
- Avoid over-indexing write-heavy tables.
- Plan retention and partitioning for audit, history, and log tables.

## ClickHouse

- Use it for analytical or reporting workloads, not transactional entity workflows.
- Optimize for append-heavy reads and aggregations, not row-by-row updates.
- Check partitioning, ordering, and retention together.
- Avoid pretending ClickHouse tables are JPA-managed OLTP tables.
- Keep ingestion, deduplication expectations, and freshness guarantees explicit in project docs.
