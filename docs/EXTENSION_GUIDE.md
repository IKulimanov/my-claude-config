# Extension Guide

## Decision Rule: Where Should New Guidance Live?

Add a new item to `rules/` only if all of these are true:
- it applies to almost every project
- it changes rarely
- it is short enough to justify always-on tokens
- violating it creates real cost or risk

Add a new item to `commands/` when:
- the workflow has a stable sequence
- you want consistent outputs
- the task is repeated often

Add a new item to `agents/` when:
- the task needs judgment or tradeoff analysis
- a fixed checklist is not enough
- you want a clear role boundary

Add a new item to `skills/` when:
- the knowledge is domain-specific
- you do not want it always loaded
- it can be reused across projects or sessions

Add a new hook when:
- the mistake is costly and recurrent
- the detection rule is simple and reliable
- false positives will stay low

## Good First Extensions

- a stack overlay skill for your primary runtime
- a code-generation command for your most common feature flow
- a project onboarding command for large repositories
- a prompt review skill for agent/system prompt changes
- a release-review command if you ship frequently

## Anti-Patterns

- putting every preference into global rules
- creating many overlapping skills
- making commands that are just long prompt dumps
- hiding project-specific constraints in global files
- adding hooks for stylistic nits instead of real risk

## Review Checklist Before Adding Anything

- What failure mode does this solve?
- Does it belong globally or locally?
- Is the guidance stable enough to stay maintainable?
- Could this be a skill instead of a rule?
- Could this be a command instead of another long prompt?
- How will I know it improved outcomes?

## Suggested Growth Order

1. Project `CLAUDE.md`
2. Skills
3. Commands
4. Agents
5. Rules
6. Hooks

This order keeps token cost and maintenance burden under control.
