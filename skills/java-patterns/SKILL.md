---
name: java-patterns
description: Use when designing new abstractions, choosing between implementation approaches, or refactoring toward clean patterns. Covers SOLID principles, GOF design patterns in Java/Spring context, functional Java idioms, and common anti-patterns.
---

# Java Patterns

Use this skill when design decisions matter: introducing a new abstraction, choosing between approaches, or evaluating whether a proposed structure is clean and maintainable.

## When To Use

- Designing a new component and choosing the right pattern
- Refactoring toward SOLID principles
- Evaluating trade-offs between two implementation approaches
- Working with functional interfaces, Optional, or Stream API
- Identifying and fixing anti-patterns in existing code
- Architecture review of a single class or module

## Workflow

1. Identify the actual problem being solved - not just "which pattern fits".
2. Load `references/design-patterns.md` for GOF pattern guidance in Spring/Java context.
3. Load `references/solid-java.md` for SOLID, Clean Code, and Java idiom guidance.
4. Recommend the simplest solution that solves the problem.
5. When Spring is involved, check whether the framework already provides the abstraction (e.g., `ApplicationEvent` for Observer, `@Component` registry for Strategy).

## Guardrails

- Do not introduce a pattern unless it reduces complexity in the current codebase.
- Keep inheritance depth <= 2; prefer composition.
- `Optional` is for return types - not parameters, not fields.
- Use streams for transformations, not side effects; for side effects prefer plain loops.
- Functional interfaces should express intent in their name, not just type: `UserValidator`, not `Function<User, Boolean>`.
- Factory patterns in Spring are often just `@Bean` methods - do not add a factory class unless there is runtime variation.
- Avoid premature abstraction: three similar methods are better than a wrong abstraction.
