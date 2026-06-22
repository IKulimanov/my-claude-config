---
name: jpa-db-review
description: Review JPA, Hibernate, SQL, and migration changes in Java services. Use when a task touches entities, repositories, native queries, Oracle, PostgreSQL, ClickHouse, indexing, retention, or rollout safety.
paths: "**/*Entity.java,**/*Repository.java,**/migration/**,**/db/**,**/*.sql"
---

# JPA And DB Review

Use this skill for changes in entities, repositories, SQL, schema, indexes, or workload-sensitive data paths.

## Review Checklist

- Are entity and model boundaries preserved?
- Is the transaction scope appropriate?
- Is there risk of entity leakage beyond the data-owning layer?
- Could the change introduce N+1, lazy-loading surprises, or excessive query count?
- Is a long derived query name hiding a query that should be explicit?
- Are native query params in `snake_case`?
- Do index changes match actual query patterns?
- Is there retention and partitioning for tables that only grow?
- Is the change safer for OLTP or OLAP workloads?
- Does rollout need compatibility or backfill steps?

## When ClickHouse Is Involved

Load `references/vendor-notes.md` and check the workload fit explicitly.
