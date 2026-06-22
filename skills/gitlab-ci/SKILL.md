---
name: gitlab-ci
description: Use when writing or reviewing GitLab CI/CD pipelines. Covers pipeline structure, stages, caching, artifacts, Docker-in-Docker, variables, environments, templates, and branch strategies for Java/Spring services.
---

# GitLab CI

Use this skill when creating or modifying `.gitlab-ci.yml`, GitLab runner configuration, or CI/CD workflows.

## When To Use

- Writing a new `.gitlab-ci.yml` from scratch
- Adding or restructuring pipeline stages
- Setting up caching for Maven or Docker layers
- Configuring protected environments and deployment gates
- Troubleshooting failing pipelines or runner issues
- Setting up merge request pipelines vs push pipelines

## Workflow

1. Read the local `CLAUDE.md` and identify: the project type, deployment targets, and branch strategy.
2. Load `references/gitlab-ci-pipeline.md` for pipeline structure and patterns.
3. For Docker-related CI steps, also load the `docker` skill.
4. For Kubernetes deploy steps, also load the `kubernetes` skill.
5. Plan the pipeline stages before writing YAML.
6. Validate: check that no secrets are hardcoded, all variables are masked, artifacts are scoped.

## Core Stages for Java/Spring Service

```
build → test → package → docker-build → deploy-staging → deploy-prod
```

- `build` — `mvn compile`
- `test` — `mvn verify` (unit + integration)
- `package` — `mvn package -DskipTests`, produces the JAR artifact
- `docker-build` — build and push image
- `deploy-staging` — auto on `master`/main
- `deploy-prod` — manual gate (`when: manual`)

## Guardrails

- Never hardcode secrets or tokens in `.gitlab-ci.yml` — use masked CI/CD variables.
- Pin Docker images to specific versions/digests in CI, not `latest`.
- Use `rules:` over `only:`/`except:` — it is more explicit and composable.
- Set `interruptible: true` on build/test jobs so new pushes cancel stale pipelines.
- Use `needs:` for DAG parallelism; do not serialize jobs that can run in parallel.
- Scope artifacts narrowly — large artifacts slow down every downstream job.
- Use `cache:` with a `key` based on the lockfile (`pom.xml` hash) to avoid stale caches.
- Protect production environments: require manual approval + limit who can trigger.
- Use `extends:` or `!reference` to avoid YAML duplication.
