---
description: Write tests for a specified class or method. Auto-detects the stack, chooses the correct test layer, and delegates to the appropriate test-writer agent.
argument-hint: <class/method/file to cover with tests>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent
---

# Test

Write tests for the specified class, method, or module.

## Workflow

### Step 1 — Detect stack and load context

1. Read the local `CLAUDE.md`.
2. Detect the stack and delegate:
   - **Java/Spring**: load `testing` skill → delegate to `test-writer` agent.
   - **Go**: load `go-best-practices/references/testing.md` → delegate to `go-test-writer` agent.
   - **Vue/JS**: load `vue-frontend/references/testing-vue.md` → delegate to `vue-test-writer` agent.

### Step 2 — Analyze the target

1. Read the class/method/module under test.
2. Inspect existing tests to match naming convention and style.
3. Identify the correct test layer:

**Java:**
| Target | Layer |
|---|---|
| Pure logic, no Spring | Unit: JUnit 5 + Mockito |
| Controller + serialization | `@WebMvcTest` |
| Repository + SQL | `@DataJpaTest` + Testcontainers |
| Kafka consumer/producer | `@EmbeddedKafka` or Testcontainers |
| Cross-layer wiring | `@SpringBootTest` |

**Vue:**
| Target | Layer |
|---|---|
| Composable / utility | Vitest unit test |
| Component rendering + events | Vue Test Utils + mount |
| Store logic | Pinia testing utils |

**Go:**
| Target | Layer |
|---|---|
| Pure function | Table-driven unit test |
| HTTP handler | httptest |
| DB interaction | Testcontainers |

### Step 3 — Write tests

1. Cover: happy path, edge cases, failure cases.
2. Follow team naming: `methodName_shouldBehavior_whenCondition`.
3. Use strong assertions (AssertJ for Java, expect for JS, testify for Go).
4. One test = one clear business contract.
5. Apply the 7-point test checklist (see `testing` skill).

### Step 4 — Report

```text
## Tests Written: <target>

### Layer
<chosen layer and why>

### Coverage
- <scenario 1>
- <scenario 2>
- ...

### Gaps
- <what was intentionally left out and why>

### Validation
- <test command> — <result>
```
