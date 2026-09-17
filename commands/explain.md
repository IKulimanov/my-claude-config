---
description: Deep explanation of any technology, pattern, or practice. Structured: what it is → why it exists → how it works → when to use → practical example (Java/Spring, Go, or Web) → common pitfalls.
argument-hint: <topic to explain>
allowed-tools: Read, Grep, Glob
---

# Explain

Use this command when you need a clear, deep explanation of a technology, framework concept, design pattern, architectural practice, or any technical topic.

Not a quick definition — a structured explanation that builds real understanding.

## Workflow

### Step 1 — Clarify the topic

If the topic is ambiguous, ask one targeted question:
- "Explain transactions" → ask: JPA/Spring transactions specifically, or the general concept?
- "Explain CQRS" → ask: as a general pattern, or for implementation in your specific stack?

Do not ask if the topic is already clear.

### Step 2 — Load relevant context

- If the topic is Java/Spring specific: load `java-patterns` or `spring-best-practices` as needed.
- If the topic is Go specific: load `go-best-practices` and relevant references.
- If the topic is Vue/frontend specific: load `vue-frontend` and relevant references.
- If the topic is infrastructure: load the relevant DevOps skill (`kubernetes`, `gitlab-ci`, etc.).
- Read the local `CLAUDE.md` if the explanation should be grounded in the project's actual stack.

### Step 3 — Produce structured explanation

Use this structure every time:

```
## What It Is
One-paragraph definition. No jargon without immediate explanation.

## Why It Exists (Problem It Solves)
What problem existed before this solution? What is it optimizing for?

## How It Works
Internal mechanics. Enough detail to predict behavior, not just use it.
Use a diagram (ASCII or text) when structure or flow is the point.

## When To Use
Specific conditions that make this the right choice.

## When NOT To Use
Conditions where this would be wrong or over-engineered.

## Practical Example
Working code example grounded in the project's stack (Java/Spring, Go, or Web).
No toy examples — use realistic domain names and scenarios.

## Common Pitfalls
2–4 specific mistakes people make with this. Not general advice.

## Further Reading (if relevant)
2–3 specific references, not a list of everything ever written.
```

### Step 4 — Connect to the project context

If a local `CLAUDE.md` exists and the topic is directly relevant to the project:
- Point out where this concept applies in the codebase
- Flag if the current code violates or correctly applies the pattern

## Tone

- Use analogies when they make the concept clearer, not just for decoration.
- Be direct about trade-offs — avoid "it depends" without explaining what it depends on.
- If the topic has competing schools of thought, present them with their trade-offs rather than picking arbitrarily.
