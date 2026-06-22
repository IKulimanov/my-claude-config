---
description: Develop a feature with plan-first flow. Auto-detects the stack (Java/Spring, Go, Vue/Vite), loads relevant skills, maps affected layers, asks clarifying questions, then implements step by step with tests.
argument-hint: <feature description or Jira ID>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent
---

# Feature Development

Use this command for any new feature or significant change. It enforces a plan-first flow and automatically loads the skills needed based on the detected stack.

## Workflow

### Step 1 — Load context and detect stack

1. Read the local `CLAUDE.md`.
2. Detect the stack:
   - **Java/Spring**: `pom.xml` or `build.gradle` → Spring Boot version, modules (JPA, Kafka, REST, Security)
   - **Go**: `go.mod` → Go version, main packages, HTTP framework
   - **Vue/Vite**: `package.json` with `vue` dependency, `vite.config.ts` → Vue version, Pinia, Router, TypeScript
   - **Web (other)**: `package.json` without Vue, or static HTML → bundler, CSS framework
3. **Detect project type:** if cwd is under `/Users/ivankulimanov/dev/work/` → WORK project, canonical convention applies.
   For Java work projects: load `java-service-convention` skill — it will redirect you to the canonical convention at `/Users/ivankulimanov/dev/work/java/convention-java/docs/`.
4. Restate the requirement in concrete technical terms before planning.

### Step 2 — Auto-detect and load skills

#### Java/Spring
| What is touched | Load |
|---|---|
| Any Java code | `java-service-convention` |
| Spring beans, config, Security, Async, Cache | `spring-best-practices` |
| Code structure, new abstractions, patterns | `java-patterns` |
| JPA entities, repositories, SQL, schema | `jpa-db-review` |
| Kafka consumers/producers, REST clients | `integration-patterns` |
| Tests (always) | `testing` |

#### Go
| What is touched | Load |
|---|---|
| Any Go code | `go-best-practices` |
| HTTP handlers, middleware, routing | `go-best-practices` + `web-app` (if serving HTML) |
| Concurrency, goroutines | `go-best-practices/references/concurrency.md` |
| Tests (always) | `go-best-practices/references/testing.md` |

#### Vue/Vite
| What is touched | Load |
|---|---|
| Components, composables | `vue-frontend` |
| Pinia stores | `vue-frontend/references/state-routing.md` |
| Router | `vue-frontend/references/state-routing.md` |
| Tests (always) | `vue-frontend/references/testing-vue.md` |

#### Always
| What is touched | Load |
|---|---|
| Docker, CI, K8s | relevant DevOps skill |
| Git branching, commit messages | `git-convention` |

### Step 3 — Map affected layers

List every layer the feature will touch:

**Java/Spring:**
```text
- [ ] Controller / API
- [ ] Service / Domain
- [ ] Repository / Data access
- [ ] Configuration
- [ ] Messaging (Kafka)
- [ ] External integrations (REST)
- [ ] Tests (unit + integration)
- [ ] DB migration (Liquibase/Flyway)
```

**Go:**
```text
- [ ] Handler / Transport
- [ ] Service / Use cases
- [ ] Repository / Data access
- [ ] Configuration
- [ ] Middleware
- [ ] External integrations
- [ ] Tests
- [ ] DB migration
```

**Vue/Vite:**
```text
- [ ] Components (new / modified)
- [ ] Composables
- [ ] Pinia stores
- [ ] Router (new routes / guards)
- [ ] API layer (fetch/axios calls)
- [ ] Types / interfaces
- [ ] Tests (unit + component)
- [ ] Build / env config
```

### Step 4 — State open questions

Surface ambiguities that would lead to wrong implementation:
- Missing requirements (edge cases, error behavior, validation rules)
- Design decisions with real trade-offs
- External dependencies that need coordination (schema change, API contract)
- Rollout risks (backward compatibility, data migration)
- Security considerations

**Do not ask about obvious things. Only surface genuine blockers.**

### Step 5 — Produce phased implementation plan

Present the plan for approval before implementing:

```text
# Feature Plan: <name>

## Summary
<what is changing and why>

## Stack
<detected stack and key details>

## Affected Layers
...

## Open Questions
- ...

## Implementation Steps
1. <step> — <file(s)>
2. ...

## Tests
- Unit: <what and why>
- Integration/Component: <what and why>

## Migration (if applicable)
- <schema or data change>
```

**Wait for approval or answers to open questions.**

### Step 6 — Implement step by step (TDD-first, iron law)

After approval, for each step:
1. **RED:** Write the failing test FIRST (or let the user write it — see test authorship in `rules/06-tdd-discipline.md`). Run it. Confirm it fails for the right reason.
2. **GREEN:** Write the minimal production code to make the test pass. Run it. Confirm green.
3. **REFACTOR:** Clean up code and test without changing behavior. Re-run tests.
4. Only THEN move to the next step.

If you cannot write a failing test first (e.g., genuine UI-only change with no behavior to assert), pause and discuss before proceeding. See `rules/06-tdd-discipline.md`.

If an unexpected complication arises, pause and report before continuing.

### Step 7 — Validate and report

Run the appropriate validation:
- **Java**: `mvn verify` (or from `CLAUDE.md`)
- **Go**: `go test ./... && go vet ./...`
- **Vue/Vite**: `npm run test` or `npx vitest run`
- Report what was verified and flag any residual risks.
