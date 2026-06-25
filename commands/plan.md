---
description: Create an implementation plan before making non-trivial code changes
argument-hint: <task description or Jira ID>
allowed-tools: Read, Grep, Glob, Bash, Write
---

# Plan

Use this command when the task is ambiguous, multi-file, high-risk, or likely to change behavior.

## Workflow

1. Read the project's `CLAUDE.md` and the most relevant source files.
2. Restate the requirement in concrete terms.
3. Identify affected files and any unknowns.
4. List edge cases, dependencies, and risks.
5. Propose a phased implementation plan.
6. Define the validation and tests needed.
7. Wait for approval before large changes.

## Persist to `.ai/` (light convention)

When working inside a repo, save the plan as a durable artifact (see `docs/AI_ARTIFACTS.md`):

```bash
DIR=$(~/dev/my-claude-config/scripts/helpers/ai-init.sh "<task>")   # creates .ai/<task>/, gitignores .ai/
```

Write the plan below to `$DIR/plan.md`. Optional for trivial tasks.

## Output Format

```text
# Plan: <task>

## Summary
<what is changing and why>

## Files
- path - reason

## Risks
- risk - mitigation

## Steps
1. ...
2. ...
3. ...

## Validation
- test or command
- test or command
```
