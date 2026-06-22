---
name: repo-onboarding
description: Rapidly map an unfamiliar repository with minimal context usage. Use when starting work in a new repo or before changing a subsystem you do not know.
---

# Repo Onboarding Skill

Map the repository before proposing changes.

## When to Use

- entering a new repository
- entering an unfamiliar subsystem
- before planning a multi-file change
- when build/test commands or architecture are unclear

## Workflow

1. Read the top-level docs and local `CLAUDE.md`.
2. Identify the build, test, lint, and run commands.
3. Map the entry points and top-level modules.
4. Identify the files closest to the requested change.
5. Check tests, fixtures, and examples around that area.
6. Summarize the architecture in a compact form.
7. State unknowns explicitly instead of guessing.

## Output Format

```text
## Repo Map
- Purpose:
- Stack:
- Entrypoints:
- Core modules:
- Test strategy:
- Local constraints:
- Unknowns:
- Next files to inspect:
```

## Guardrails

- Do not read the entire repo by default.
- Prefer targeted reads over bulk loading.
- Prefer manifests, docs, and tests before deep implementation files.
