---
description: Quick convention compliance check for Java code. Faster and more focused than full review — only checks convention drift.
argument-hint: [optional path or class]
allowed-tools: Read, Grep, Glob, Bash
---

# Convention Check

Fast, focused check of Java code against the team convention. No architecture review, no optimization suggestions — only convention compliance.

**Optimized for speed and low token usage.**

## Step 0 — Load the authoritative rule set (work projects)

For a WORK project (cwd under `~/dev/work/`), the source of truth is the generated Sonar-aligned
checklist: `~/dev/my-claude-config/skills/java-service-convention/references/sonar-rules.md`. Read
it and check the diff **against those exact codes** (LANG-/SPR-/DB-) — they match what CI Sonar
enforces, so your findings predict the quality gate. If the file is missing (personal project, or
not on the work machine), fall back to the built-in list below.

**This is a local pre-filter. The authoritative verdict is CI Sonar (`mvn verify sonar:sonar
-Dsonar.qualitygate.wait=true`).** Never claim the code "passes convention" — say it passes the
local pre-check; CI Sonar decides.

## What Is Checked (fallback list for personal projects / when checklist is absent)

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

### Data Access (SPR, DB)
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
2. Check against **Step 0's Sonar-aligned checklist** (`sonar-rules.md` codes) on work projects; use
   the fallback list above only if that checklist was unavailable.
3. Report only violations — no praise, no style suggestions.

`sonar-rules.md` is internal team material — cite rule codes (e.g. `SPR-902`); do not paste its
prose or code examples verbatim into shared outputs.

## Output Format

```text
## Convention Check: <scope>

### Violations
- LANG-103: <file>:<line> — <violation>
- SPR-902: <file>:<line> — <violation>
- ...
(use the real codes from `sonar-rules.md`; do not invent codes)

### Clean
<list categories with no violations>

### Summary
<N violations found across M categories>
```

If no violations found (work project): `Локальный предчек пройден — нарушений по кодам конвенции не
найдено. Финальный вердикт даёт CI Sonar.` For a personal project: `All checked code complies with
the convention guardrails.`
