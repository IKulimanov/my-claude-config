---
name: go-best-practices
description: Use when writing or reviewing Go code. Covers project layout, error handling, concurrency, interfaces, testing, and idiomatic Go patterns.
paths: "**/*.go"
---

# Go Best Practices

Use this skill for all Go development and review work.

## When To Use

- Writing new Go services or CLI tools
- Reviewing Go code for correctness and idiom compliance
- Designing package structure and API boundaries
- Working with concurrency (goroutines, channels, sync primitives)
- Writing or reviewing tests
- Optimizing performance or memory usage

## Workflow

1. Read the local `CLAUDE.md` for Go version, module path, and project constraints.
2. Load the relevant reference based on the task:
   - `references/project-structure.md` - layout, packages, dependency management
   - `references/error-handling.md` - error wrapping, sentinel errors, error types
   - `references/concurrency.md` - goroutines, channels, context, sync primitives
   - `references/testing.md` - table-driven tests, testify, httptest, benchmarks
3. Inspect existing code to match the project's style before writing new code.

## Guardrails

- Prefer the standard library over third-party packages unless there is a clear benefit.
- Return errors explicitly - never panic for expected failures.
- Always propagate `context.Context` as the first parameter.
- Keep interfaces small (1-3 methods); define them where they are consumed, not where they are implemented.
- Use `struct` embedding for composition, not inheritance simulation.
- Avoid `init()` - prefer explicit initialization.
- Never ignore errors with `_` unless the function contract guarantees safety.
- Use `go vet`, `staticcheck`, and `golangci-lint` as baseline quality checks.
- Keep goroutine lifecycle explicit - every goroutine must have a clear shutdown path.
- Prefer `sync.WaitGroup` or `errgroup.Group` over bare goroutine spawning.
- Use `defer` for cleanup, but be aware of loop-scope captures.
