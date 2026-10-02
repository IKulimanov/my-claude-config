---
name: testing
description: Use when writing or reviewing tests in Java/Spring. Covers JUnit 5, Mockito, AssertJ, Spring Boot Test slices (@WebMvcTest, @DataJpaTest, @SpringBootTest), Testcontainers, test architecture, naming conventions, and test data patterns.
paths: "**/*Test.java,**/*Tests.java,**/*IT.java"
---

# Testing

Use this skill for all test writing and test review work in Java/Spring projects.

## When To Use

- Writing unit tests for service or domain logic
- Writing controller tests with `MockMvc`
- Writing repository tests with `@DataJpaTest` + Testcontainers
- Writing full integration tests with `@SpringBootTest`
- Reviewing test coverage and test quality
- Setting up test data builders or fixtures
- Async assertion or timing-sensitive tests

## Workflow

1. Identify the layer under test and choose the narrowest context that gives confidence:
   - Pure logic (no Spring) -> JUnit 5 + Mockito, no context
   - Controller layer -> `@WebMvcTest`
   - Repository layer -> `@DataJpaTest` + Testcontainers
   - Full slice / wiring test -> `@SpringBootTest`
2. Load `references/unit-testing.md` for JUnit 5 + Mockito + AssertJ guidance.
3. Load `references/integration-testing.md` for Spring Boot Test and Testcontainers.
4. Write tests before or alongside the implementation, not as an afterthought.
5. Verify that tests pass in isolation and in any order.

## Naming Convention

Pick one and apply consistently across the service:
- `methodName_shouldDoX_whenY` (method-centric)
- `givenY_whenMethodName_thenX` (BDD-style)

## Guardrails

- Never use `@SpringBootTest` when `@WebMvcTest` or `@DataJpaTest` is enough.
- Do not mock what you can test for real (Testcontainers over mocking the DB).
- Each test should have a single logical assertion; use `SoftAssertions` for compound checks.
- Test behavior, not implementation: mock external dependencies, not internals of the class under test.
- Never use `Thread.sleep` - use Awaitility for async assertions.
- Keep test data construction explicit: use builders or test factories, not large shared fixture files.
- `@MockBean` replaces the bean in the Spring context - use sparingly; prefer `@Mock` with `MockitoExtension` in unit tests.
- Do not share mutable test state across test methods.
