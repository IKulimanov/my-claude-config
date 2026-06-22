---
description: Create an implementation plan before making non-trivial code changes
argument-hint: <task description or Jira ID>
allowed-tools: Read, Grep, Glob, Bash
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
