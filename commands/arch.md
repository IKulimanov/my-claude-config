---
description: Design or review architecture — from a single module to a full system. Produces design options with trade-offs, bounded contexts, interface contracts, and risks.
argument-hint: <topic or scope: local|system>
allowed-tools: Read, Grep, Glob, Bash
---

# Architecture Design

Use this command when designing new architecture or reviewing an existing design decision. Works at two scopes:
- **Local** — a single class, module, or service layer
- **System** — a full microservice or multi-service landscape

## Workflow

### Step 1 — Establish context

1. Read the local `CLAUDE.md` to understand the service and its constraints.
2. **Project type:** if cwd is under `/Users/ivankulimanov/dev/work/` → work project. Load `java-service-convention` skill for Java work, which directs to the canonical convention at `/Users/ivankulimanov/dev/work/java/convention-java/docs/`. Design must align with canonical, not generic best practices.
3. Ask if unclear: what is the scope (single component vs. full system)?
4. Identify the primary driver: correctness, scalability, maintainability, team fit, or migration path.

### Step 2 — Load relevant skills

Load skills based on the detected stack:

**Java/Spring:**
- `java-patterns` — SOLID, GOF, Clean Code
- `spring-best-practices` — if Spring beans, configuration, or security are involved
- `jpa-db-review` — if the design involves data access or schema
- `integration-patterns` — if the design involves Kafka, REST integrations, or async flows

**Go:**
- `go-best-practices` — project structure, interfaces, dependency direction
- `go-best-practices/references/concurrency.md` — if concurrency or async flows are in scope
- `web-app` — if the service serves web content

**Web:**
- `web-app` — security, performance, rendering patterns
- `web-app/references/security.md` — if auth, CSP, or session design is in scope
- `go-best-practices` — if Go is the backend

### Step 3 — Map the problem

For **local scope:**
- Identify the responsibility boundary of the component being designed
- List dependencies (what does it need? what depends on it?)
- Identify variation points (what is likely to change?)
- Identify invariants (what must always be true?)

For **system scope:**
- Identify bounded contexts and their ownership
- Map synchronous vs. asynchronous interactions
- Identify shared data and avoid implicit coupling
- Identify failure modes and cascade risks

### Step 4 — Produce design options

For non-trivial decisions, present 2–3 options with clear trade-offs:

```
Option A: [name]
  Description: ...
  Pros: ...
  Cons: ...
  Best when: ...

Option B: [name]
  ...

Recommended: [option] because [reason tied to the stated driver]
```

### Step 5 — Define contracts and risks

- Define public interfaces and their contracts (what they guarantee, what they require)
- Identify seams where testing is needed
- Flag rollout risks: breaking changes, migration steps, backward-compatibility requirements

### Step 6 — Wait for approval before implementation

Do not write production code until the design has been reviewed. If the scope is small, note that code can proceed after this step.

## Output Format

```text
# Architecture: <topic>

## Scope
<local | system>

## Context
<what exists today, what is changing, and why>

## Design Options

### Option A: <name>
...

### Option B: <name>
...

## Recommended Approach
<option + rationale>

## Contracts and Interfaces
- <component>: <what it owns, what it exposes>

## Risks
- <risk>: <mitigation>

## Next Steps
1. ...
```

## After the decision

If the user accepts an option that changes technology, a pattern with consequences, or an earlier design decision —
record it as an ADR via `/adr` (rules and template: `~/dev/my-claude-config/playbook/templates/adr-template.md`).
Do not inline the ADR into this output; the ADR is a separate file in the repo's `docs/adr/`.
