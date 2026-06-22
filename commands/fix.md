---
description: Lightweight quickfix for small bugs and simple changes. Minimal context loading for token efficiency.
argument-hint: <bug description or file:line>
allowed-tools: Read, Edit, Grep, Glob, Bash
---

# Fix

Use this command for small, focused changes: bug fixes, NPE fixes, adding a field, renaming, small refactors.

**This command is optimized for minimal token usage.** It does NOT load the full skill set.

## Workflow (TDD-first)

1. Read the local `CLAUDE.md` (if exists) — only the Runbook and Invariants sections.
2. **If cwd is under `/Users/ivankulimanov/dev/work/`** → work project. For Java/Spring, load `java-service-convention` skill before changes; it will point you to the canonical convention.
3. Read only the file(s) being changed and their direct test files.
4. **RED:** Write a test that reproduces the bug (or let the user write it — see test authorship in `rules/06-tdd-discipline.md`). Run it. Confirm it fails with the symptom you're trying to fix.
5. **GREEN:** Make the smallest change that turns the test green.
6. **REFACTOR (optional):** Clean up if needed without changing behavior. Re-run test.
7. Run the full nearby test class to ensure no regression. Report results.

If the bug cannot be reproduced in a test (e.g., environment-specific), pause and discuss before patching blindly. See `rules/06-tdd-discipline.md`.

## What This Command Is NOT For

- New features (use `/feature`)
- Architecture changes (use `/arch`)
- Multi-file refactors (use `/plan` first)
- Database/schema changes (use `/migration-plan`)

## Output Format

```text
## Fix: <brief description>

### Change
- <file>:<lines> — <what changed and why>

### Test
- <test file> — <what is tested>

### Validation
- <command run> — <result>
```

## Rules

- Do not load skills unless explicitly needed.
- Do not explore unrelated files.
- Do not refactor surrounding code.
- If the fix turns out to be non-trivial, stop and suggest using `/plan` or `/feature` instead.
