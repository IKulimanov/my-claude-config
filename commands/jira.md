---
description: Generate a well-structured Jira task description in Jira markdown. Covers feature, bug, tech debt, and spike task types. Produces Summary, Background, Acceptance Criteria, Technical Notes, Out of Scope, and DoD.
argument-hint: <task brief: feature|bug|tech-debt|spike + short description>
allowed-tools: Read, Grep, Glob
---

# Jira Task Description

Use this command to produce a complete Jira task description from a brief or detailed context you provide.

## What to Provide

You can give anything from a rough idea to a detailed spec. The more context, the less I will need to infer:
- Feature name or bug description
- Affected service or module (or it will be inferred from `CLAUDE.md`)
- Known constraints, deadlines, or stakeholder requirements
- What is explicitly out of scope (if known)

## Workflow

### Step 1 — Identify task type

| Type | When |
|---|---|
| **Feature** | New functionality |
| **Bug** | Incorrect behavior in production or staging |
| **Tech Debt / Refactoring** | Internal improvement, no new user-visible behavior |
| **Spike / Research** | Investigation with a time-box, produces a decision or doc |

### Step 2 — Read context

If a `CLAUDE.md` exists in the project, read it to understand:
- The service boundary and its domain
- The tech stack (affects Technical Notes)
- Any known constraints (e.g., "no schema changes without DBA approval")

### Step 3 — Ask for missing critical info

If the task type is ambiguous or key info is missing, ask one focused question before generating. Do not ask about optional fields — infer or leave them as `[TBD]`.

### Step 4 — Generate the description

Output in **Jira markdown** (Jira uses `*bold*`, `_italic_`, `# heading`, `{code}` blocks):

---

## Output Template

```
h2. Background

[Why this task exists. What problem it solves or what value it delivers.
Link to related tasks or external context if available.]

h2. Acceptance Criteria

# [Criterion 1 — testable, user-visible or system-observable]
# [Criterion 2]
# [Criterion 3]

h2. Technical Notes

[Implementation approach, constraints, or key decisions already made.
Mention affected services, APIs, DB changes, or infrastructure.
Leave [TBD] for open design decisions.]

h2. Out of Scope

* [What is explicitly NOT included in this task]
* [Related work deferred to a follow-up]

h2. Definition of Done

* Code reviewed and merged to staging
* Unit and integration tests written and passing
* No new SonarQube critical issues
* [Any additional DoD specific to the task: migration tested, load tested, docs updated, etc.]

h2. Story Point Estimate

[If requested: S/M/L/XL or Fibonacci. Include brief rationale.]
```

---

## Bug Task Variant

For bugs, replace *Background* + *Acceptance Criteria* with:

```
h2. Problem Description

[What is broken. Observed vs. expected behavior.]

h2. Steps to Reproduce

# [Step 1]
# [Step 2]
# [Expected result]
# [Actual result]

h2. Impact

[Who is affected, how often, severity: P1/P2/P3]

h2. Root Cause Hypothesis

[If known or partially understood]

h2. Acceptance Criteria (Fix Verified When)

# [Test condition that confirms fix]
```

---

## Spike Task Variant

For spikes, add a time-box and expected output:

```
h2. Goal

[What decision or understanding this spike must produce]

h2. Time Box

[e.g., 2 days]

h2. Expected Output

* Document or ADR describing the recommendation
* [Or: PoC code in a separate branch]
* [Or: Comparison table of options]
```
