---
description: Plan and review schema, query, and data-access changes before implementation
argument-hint: <schema/query/entity change description>
allowed-tools: Read, Grep, Glob, Bash
---

# Migration Plan

Use this workflow for:
- new tables or columns
- index changes
- JPA mapping changes
- native query changes
- Oracle/PostgreSQL schema work
- retention or partitioning changes

## Workflow

1. Describe the functional change.
2. Identify affected data stores and workload type: OLTP, OLAP, or mixed.
3. Identify backward-compatibility and rollout concerns.
4. Review indexes, retention, partitioning, and query patterns.
5. Propose the migration sequence and validation plan.
6. Wait for approval before implementation.

## Output Format

```text
# Migration Plan

## Goal

## Data Stores
- Oracle / PostgreSQL / ClickHouse

## Risks
- compatibility
- locks
- query regressions
- rollback

## Steps
1. ...
2. ...
3. ...

## Validation
- explain analyze / query check
- tests
- rollout verification
```
