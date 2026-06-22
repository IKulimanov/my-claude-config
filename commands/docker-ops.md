---
description: Plan or review Docker and Docker Compose changes — Dockerfiles, compose configs, local dev setup, image optimization, and container debugging.
argument-hint: [optional task: dockerfile|compose|dev|debug]
allowed-tools: Read, Edit, Write, Grep, Glob, Bash
---

# Docker Ops Command

Use this command when you need to plan, review, or debug Docker-related work.

## When To Use

- Writing or refactoring a Dockerfile
- Setting up or changing Docker Compose configuration
- Diagnosing a broken container or startup issue
- Optimizing image size or build times
- Setting up a local dev environment from scratch

## Workflow

### Step 1 — Load context

1. Load the `docker` skill.
2. Read the local `CLAUDE.md` to understand the project stack and constraints.
3. Inspect existing `Dockerfile`, `docker-compose*.yml`, `.dockerignore`, `.env.example`.

### Step 2 — Identify the task type

| Task | Reference to load |
|------|-------------------|
| Dockerfile authoring or review | `dockerfile.md` |
| Compose configuration | `compose.md` |
| Local dev setup | `dev-workflow.md` |
| Debugging runtime | `dev-workflow.md` + inspect logs |

### Step 3 — Assess current state

- What is the base image and is it pinned?
- Is there a `.dockerignore`? Is it excluding build artifacts?
- Are secrets handled correctly (not in Dockerfile, not in compose files)?
- Is the app running as root?
- Are healthchecks defined for services with `depends_on`?

### Step 4 — Plan changes

For Dockerfile changes:
- State the current and target image size if optimization is the goal.
- Identify layer ordering issues.
- Propose multi-stage structure if not already present.

For Compose changes:
- List services affected.
- Flag any shared volumes or networks that other developers or services depend on.
- Identify missing healthchecks.

For local dev setup:
- Confirm the one-command startup works.
- Check if `.env.example` exists and is current.
- Check for hot reload or remote debug setup if needed.

### Step 5 — Implement and validate

After changes:
- Run `docker compose config` to validate Compose syntax.
- Run `docker compose build` to confirm Dockerfile builds.
- Run `docker compose up -d` and check `docker compose ps` for healthy services.
- Report what was verified.

## Output Format

```text
## Docker Ops Summary
- Task:
- Files changed:
- Key decisions:
- Risks or caveats:
- Validation performed:
- Next steps (if any):
```
