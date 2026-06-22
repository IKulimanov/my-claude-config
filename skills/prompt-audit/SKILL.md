---
name: prompt-audit
description: Audit prompts and config files for ambiguity, overlap, unsafe assumptions, and token bloat. Use when refining agent instructions or combining multiple prompt layers.
---

# Prompt Audit Skill

Audit a prompt or configuration as a control system, not as prose.

## Audit Dimensions

1. Clarity
- Are instructions specific and testable?
- Are terms like "best", "good", or "latest" grounded enough?

2. Layering
- Does the guidance belong in this file?
- Is project-local content incorrectly placed in a global layer?

3. Conflicts
- Do any instructions contradict each other?
- Is there a collision between autonomy and approval requirements?

4. Scope control
- Is the agent told what not to do?
- Are destructive actions, network access, or wide edits bounded?

5. Token discipline
- Is the always-on text too large?
- Could examples or edge guidance move into a skill?

6. Evaluation
- Can a reviewer tell whether the prompt worked?
- Are outputs structured enough to inspect?

## Output Format

```text
## Prompt Audit
- Strengths:
- Conflicts:
- Ambiguities:
- Control gaps:
- Token bloat sources:
- Recommended moves between layers:
- Minimal revised structure:
```
