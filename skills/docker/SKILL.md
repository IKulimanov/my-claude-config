---
name: docker
description: Use when working with Docker and Docker Compose — writing or reviewing Dockerfiles, compose configurations, local dev environments, container debugging, and image optimization.
---

# Docker Skill

Use this skill when the task involves containerization, local Docker environments, or Compose-based service orchestration.

## When To Use

- Writing or reviewing Dockerfiles
- Designing or debugging Docker Compose setups
- Setting up local dev environments with containers
- Optimizing image size or build cache
- Debugging container runtime issues
- Configuring networking, volumes, or environment variables
- Setting up multi-stage builds for Java or Go services

## Workflow

1. Read the local project `CLAUDE.md` first.
2. Check existing `Dockerfile` and `docker-compose*.yml` if present.
3. Read the reference most relevant to the task:
   - `references/dockerfile.md` — image authoring, multi-stage builds, layer caching
   - `references/compose.md` — service definitions, networking, volumes, profiles
   - `references/dev-workflow.md` — local dev patterns, hot reload, debugging
4. Identify the target environment (local dev vs CI vs prod image).
5. Plan changes before modifying existing Compose files that other services depend on.

## Guardrails

- Never put secrets or credentials in Dockerfiles or Compose files — use environment variables or secrets mounts.
- Prefer multi-stage builds to keep production images lean.
- Do not run containers as root unless the task explicitly requires it.
- Keep `CMD` and `ENTRYPOINT` explicit and predictable.
- Use `.dockerignore` to avoid bloating the build context.
- Prefer named volumes over anonymous volumes for persistent data.
- When modifying shared `docker-compose.yml`, treat it as a public API — flag breaking changes.
- Prefer `docker compose` (v2 plugin) over `docker-compose` (v1 standalone).
