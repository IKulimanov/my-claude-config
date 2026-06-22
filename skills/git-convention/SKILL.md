---
name: git-convention
description: Use for branch naming, commit messages, and merge flow in team Java services that follow the staging-based workflow.
---

# Git Convention

Use this skill when the task involves branch naming, commit preparation, staging merges, or release flow discussion.

## Workflow

1. Confirm whether the repository follows the team staging flow.
2. Read `references/flow.md`.
3. Apply the branch and commit naming rules.
4. If the repo documents an exception in its local `CLAUDE.md` or README, prefer the repo-local rule.

## Guardrails

- Work in dedicated branches created from `master`.
- Validate through `staging` when the repo follows that flow.
- Never merge `staging` into `master`.
- Do not create direct commits in `master` or `staging`.
