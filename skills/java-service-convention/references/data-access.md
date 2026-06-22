# Data Access Reference

## Repository And Entity Boundaries

- Structure by domain, not one giant package for all models.
- Keep JPA entities inside the data-owning layer (DAO/repository layer).
- Outside that layer, pass models or DTOs — never entities.
- Name entities with the `Entity` suffix; non-entity models without suffix.
- Work with JPA entities only in DAOs; use models for service and controller layers.

## Repository Queries

- Use generated method names for simple queries (up to 3 params, name under ~50 chars).
- For complex queries (>3 params or >50 char method names), prefer JPQL or native SQL.
- In native queries, use `snake_case` for named parameters in `@Param`.
- For native SQL outside repositories, prefer `NamedParameterJdbcTemplate`.
- Access result columns by name, not by index.
- Never concatenate SQL — use parameterized queries (prevent injection).

## Entity Conventions

- Add creation and modification timestamps using `@PrePersist` and `@PreUpdate`.
- Use Lombok `@FieldNameConstants` for type-safe `@OneToMany.mappedBy` values.
- Don't mutate JPA entities without explicit save.
- Watch `@Transactional` scope — works only via Spring proxy, not on private methods or self-calls.

## DB Connection Conventions

- Set an explicit pool name (format examples: `slrdb-lk-auth-pool`, `redknee-db-pool`).
- Set the application name / session program so DB-side diagnostics identify the service.
- Keep audit timestamps (`created_at`, `updated_at`) where table semantics justify them.

## Query Performance

- Watch for N+1 queries, lazy-loading surprises, and excessive query count.
- Prefer `JOIN FETCH` or `@EntityGraph` for known eager-loading needs.
- Use `@BatchSize` or `@Fetch(FetchMode.SUBSELECT)` for collections loaded in loops.
- Profile queries with real data volumes, not just test fixtures.
