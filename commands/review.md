---
description: Review current changes for bugs, regressions, security risks, and missing tests. Auto-detects the stack (Java/Spring, Go, Vue) and delegates to the matching reviewer agent; other stacks are reviewed directly.
argument-hint: [optional path or PR scope]
allowed-tools: Read, Grep, Glob, Bash, Agent
---

# Review

Review the current changes with a code-review mindset.

## Workflow

1. Inspect the current diff and changed files.
2. Detect the stack and route the review:

### Java/Spring → `java-reviewer` agent
- Agent auto-loads: `java-service-convention`, `jpa-db-review`, `integration-patterns`, `testing`
- Agent knows the full team convention — no need to duplicate rules here.

### Go → `go-reviewer` agent
- Agent auto-loads: `go-best-practices`

### Vue/Vite (`.vue`, `package.json` with vue) → `vue-reviewer` agent
- Agent auto-loads: `vue-frontend`

### Web (generic HTML/CSS/JS, server templates)
- No dedicated agent — load the `web-app` skill and review directly.

### DevOps (Docker, CI, K8s, Terraform)
- Load the relevant skill (`docker`, `terraform`, `gitlab-ci`, `kubernetes`, `helm`).
- No dedicated agent — review directly.

### Any other stack
- No dedicated agent — review directly with general code-review judgment.

For every directly-reviewed branch (Web, DevOps, other), apply the Output Rules and Severity Bands below.

3. Focus on correctness, behavioral regressions, and risky assumptions.
4. Check security-sensitive paths, input validation, and error handling.
5. Check whether tests cover new or changed behavior.
6. Ignore pure style nits unless they hide a real risk.

## Output Rules

- Findings come first.
- Order findings by severity.
- Include file and line references whenever possible.
- Keep each finding concrete: what is wrong, why it matters, what can break.
- Reference convention rule IDs when applicable (e.g. LANG-4, SPR-2).
- If there are no findings, state that explicitly and mention residual risks or test gaps.

## Severity Bands

- **CRITICAL**: data loss, security exposure, broken behavior, or unsafe rollout risk
- **WARNING**: likely bug, regression risk, missing validation, or serious maintainability issue
- **SUGGESTION**: lower-impact improvement worth considering
