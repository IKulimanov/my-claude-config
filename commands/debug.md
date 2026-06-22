---
description: Diagnose a bug or failing behavior before patching it
argument-hint: <symptom or failing test name>
allowed-tools: Read, Grep, Glob, Bash
---

# Debug

Use this command when there is a failing test, runtime bug, or unclear broken behavior.

## Workflow

1. Reproduce the symptom or capture the failing evidence.
2. Narrow the scope to the smallest responsible area.
3. Form explicit hypotheses for the root cause.
4. Confirm the root cause with code, logs, or tests.
5. Propose the smallest fix that addresses the confirmed cause.
6. Add a regression test when practical.

## Output Format

```text
# Debug Report: <issue>

## Symptom
<what fails>

## Evidence
- ...

## Root Cause Hypothesis
- ...

## Confirmed Cause
<what actually caused it>

## Fix Plan
1. ...
2. ...

## Validation
- ...
```
