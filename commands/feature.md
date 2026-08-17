---
description: Develop a feature with plan-first flow. Auto-detects the stack (Java/Spring, Go, Vue/Vite), loads relevant skills, maps affected layers, asks clarifying questions, then implements step by step with tests.
argument-hint: <feature description or Jira ID>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent
---

# Feature Development

Use this command for any new feature or significant change. It enforces a plan-first flow and automatically loads the skills needed based on the detected stack.

## Workflow

### Step 1-2 — Load context, detect stack, load skills

Follow the shared block: `~/dev/my-claude-config/docs/shared/stack-detection.md`. It covers reading
the local `CLAUDE.md`, detecting Java/Spring · Go · Vue/Vite · Web, detecting WORK vs personal
project, restating the requirement, and the per-stack skill-loading tables.

### Step 3 — Map affected layers

List every layer the feature will touch, using the checklist in
`~/dev/my-claude-config/docs/shared/affected-layers.md` (Java/Spring · Go · Vue/Vite).

### Step 4 — State open questions

Surface ambiguities that would lead to wrong implementation:
- Missing requirements (edge cases, error behavior, validation rules)
- Design decisions with real trade-offs
- External dependencies that need coordination (schema change, API contract)
- Rollout risks (backward compatibility, data migration)
- Security considerations

**Do not ask about obvious things. Only surface genuine blockers.**

### Step 5 — Produce phased implementation plan

Present the plan for approval before implementing, using the shared format in
`~/dev/my-claude-config/docs/shared/plan-template.md` — Russian sections, including the **mandatory
«Каким путём идём»** (explains the chosen approach and why, not just a list of steps). The plan must
let the reader follow your reasoning, not only what changes.

**Wait for approval or answers to open questions.**

#### Persist the plan to `.ai/` (light convention)

When working inside a repo, save the approved plan as a durable artifact so it survives context
compaction and follow-ups. See `docs/AI_ARTIFACTS.md`.

```bash
DIR=$(~/dev/my-claude-config/scripts/helpers/ai-init.sh "<feature>")   # creates .ai/<feature>/, gitignores .ai/
```

Write the plan to `$DIR/plan.md`. Update it as the implementation evolves. This is optional for
trivial changes.

### Step 6 — Implement step by step (TDD-first, iron law)

After approval, for each step:
1. **RED:** Author the failing test FIRST. Delegate test design to the stack's test-writer agent — Java/Spring → `test-writer`, Go → `go-test-writer`, Vue/Vite → `vue-test-writer`. The agent is read-only: it returns the test code; you write it to the test file and run it, confirming it fails for the right reason. For any other stack, write the failing test directly. (Or let the user write it — see test authorship in `rules/06-tdd-discipline.md`.)
2. **GREEN:** Write the minimal production code to make the test pass. Run it. Confirm green.
3. **REFACTOR:** Clean up code and test without changing behavior. Re-run tests.
4. Only THEN move to the next step.

If you cannot write a failing test first (e.g., genuine UI-only change with no behavior to assert), pause and discuss before proceeding. See `rules/06-tdd-discipline.md`.

If an unexpected complication arises, pause and report before continuing.

### Step 7 — Validate

Run the appropriate validation:
- **Java**: `mvn verify` (or from `CLAUDE.md`)
- **Go**: `go test ./... && go vet ./...`
- **Vue/Vite**: `npm run test` or `npx vitest run`

### Step 8 — Convention gate (Java work projects), then report

Before declaring the feature done, run the convention pre-check on the final diff so drift is caught
locally, not by CI. For a WORK Java project (cwd under `~/dev/work/`), check the diff against the
Sonar-aligned checklist `~/dev/my-claude-config/skills/java-service-convention/references/sonar-rules.md`
(codes LANG-/SPR-/DB-) — equivalent to running `/convention-check`. Fix violations with TDD, then
re-validate. This is a pre-filter: the authoritative gate is CI Sonar (`mvn verify sonar:sonar
-Dsonar.qualitygate.wait=true`). For non-Java or personal projects, skip.

`sonar-rules.md` is internal team material — cite rule codes (LANG-410, SPR-902); do not paste its
prose or code examples verbatim into shared outputs.

Only after this — report what was verified, the convention-gate result, and any residual risks.
