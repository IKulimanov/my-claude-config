# Database Design Reference

## Table Naming

- Use prefixes for related tables: `AUTH_USERS`, `AUTH_ROLES`.
- Table names: plural nouns (`USERS` not `USER`).
- Foreign key convention: `{table}_id`.
- Reflect the entity represented in the name.

## Workload Profiling

- Analyze expected load profile before schema design: OLTP vs OLAP.
- OLTP: optimize for row-level reads/writes, use selective indexes.
- OLAP/analytical: optimize for scans, aggregations, append-heavy writes.
- Design indexes and partitioning based on workload, not guesswork.

## Index Design

- Don't create B-Tree indexes on low-cardinality columns (`BOOLEAN`, small `ENUM`).
- Use Partial Indexes for rare values (e.g. `WHERE status = 'FAILED'`).
- Prefer composite indexes over multiple single-column indexes.
- One well-designed composite index > many single-column indexes.
- Design composite indexes for actual query patterns (column order matters).
- Watch index maintenance cost on write-heavy tables.

## Data Retention

- Define data retention policy at design time — don't accumulate indefinitely.
- Use time-based partitioning for easy deletion (partition drop vs slow `DELETE`).
- For ever-growing tables (audit, history, logs): retention + partitioning from day one.

## Oracle Specifics

- Use sequences for ID generation, not `IDENTITY` columns.
- Be aware of Oracle's `VARCHAR2` limit (4000 bytes) vs PostgreSQL's unlimited `TEXT`.
- Use `DBMS_STATS` for optimizer statistics after large data loads.

## PostgreSQL Specifics

- Use `TEXT` instead of `VARCHAR(n)` when length limit is arbitrary.
- Leverage `JSONB` for semi-structured data with GIN indexes.
- Use `EXPLAIN (ANALYZE, BUFFERS)` for query plan analysis.
- Consider `pg_stat_statements` for identifying slow queries.

## ClickHouse Specifics

- Use for analytical/reporting workloads only, not transactional entity workflows.
- Optimize for append-heavy reads and aggregations, not row-by-row updates.
- Check partitioning, ordering key, and retention together.
- Keep ingestion, deduplication, and freshness guarantees explicit.
- Don't pretend ClickHouse tables are JPA-managed OLTP tables.

## Migration Safety

- Backward-compatible migrations first (add column → deploy code → remove old column).
- Never drop columns in the same release that stops using them.
- Test migrations on a copy of production-scale data.
- For large tables: use online DDL or batched backfill, not blocking `ALTER TABLE`.
