---
description: Quick convention compliance check for Java code. Faster and more focused than full review — only checks convention drift.
argument-hint: [optional path or class]
allowed-tools: Read, Grep, Glob, Bash
---

# Convention Check

Fast, focused check of Java code against the team convention. No architecture review, no optimization suggestions — only convention compliance.

**Optimized for speed and low token usage.**

## What Is Checked

### Code Style (LANG)
- [ ] Package naming (`snake_case`, domain-organized)
- [ ] Class naming (PascalCase, no numbers, no vague names)
- [ ] Variable naming (camelCase, meaningful, no abbreviations)
- [ ] Method naming (correct prefixes: find/get/fetch/build, boolean as question)
- [ ] Method size (<=30 lines, <=3 params)
- [ ] Nesting depth (<=3 levels)
- [ ] No magic numbers/strings
- [ ] Nullability annotations (JSpecify)

### Spring (SPR)
- [ ] Constructor injection via `@RequiredArgsConstructor`
- [ ] Thin controllers (no business logic)
- [ ] `@Valid` on request models
- [ ] Global exception handling (no `ResponseEntity` for success)
- [ ] Separate `*Api` interface for Swagger
- [ ] No `System.out` — SLF4J only
- [ ] Parameterized logging
- [ ] Secrets masked in logs
- [ ] Schedulers disabled by default (`@ConditionalOnProperty`)

### Data Access (SPR-1, DB)
- [ ] Entity suffix on JPA entities
- [ ] Entities don't leak outside DAO layer
- [ ] `@PrePersist`/`@PreUpdate` for timestamps
- [ ] Explicit pool names
- [ ] Parameterized queries (no SQL concatenation)

### Lombok (LIB)
- [ ] `callSuper = true` when inheriting
- [ ] `@UtilityClass` for utility classes
- [ ] `@FieldNameConstants` for `mappedBy`

### Git (GIT)
- [ ] Branch format: `{type}/{JIRA-CODE}-{description}`
- [ ] Commit format: `{JIRA-CODE}: {verb-led description}`

## Workflow

1. Inspect the current diff or specified files.
2. Check each applicable category from the list above.
3. Report only violations — no praise, no style suggestions.

## Output Format

```text
## Convention Check: <scope>

### Violations
- LANG-1: <file>:<line> — <violation>
- SPR-2: <file>:<line> — <violation>
- ...

### Clean
<list categories with no violations>

### Summary
<N violations found across M categories>
```

If no violations found: `All checked code complies with the team convention.`
