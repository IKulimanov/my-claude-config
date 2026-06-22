---
name: agent-design
description: Design or review agent workflows, tool boundaries, approval gates, and evaluation loops. Use when creating or refactoring agents, skills, commands, or orchestration prompts.
---

# Agent Design Skill

Design agents that are controllable, testable, and cheap to operate.

## Design Checklist

1. Objective
- What exact outcome is the agent responsible for?
- What is explicitly out of scope?

2. Inputs and context
- What must always be present?
- What should stay project-local?
- What should load on demand only?

3. Tools
- Which tools are truly required?
- Which tools are read-only vs mutating?
- Which tool calls require human approval?

4. Execution model
- Is this a fixed workflow, a specialist role, or a reusable knowledge pack?
- Should this be a command, agent, or skill?

5. Stop conditions
- When should the agent stop and ask?
- When should it refuse or escalate?
- What counts as success?

6. Validation
- What evidence proves the task is complete?
- What tests or checks must run?

7. Observability
- What should the agent log or summarize after acting?
- What should be easy for a human to review?

## Common Failure Modes

- one prompt contains multiple conflicting roles
- too many tools for the same responsibility
- missing approval boundary for writes or external actions
- no explicit stop condition
- project-specific constraints hidden in a global prompt
- huge always-on instructions instead of modular loading

## Output Format

```text
## Agent Design Review
- Objective:
- Layer choice: rule / command / agent / skill
- Required tools:
- Approval boundary:
- Stop conditions:
- Validation:
- Main risks:
- Recommended changes:
```
