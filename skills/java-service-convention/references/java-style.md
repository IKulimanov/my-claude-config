# Java Style Reference

## Naming

- Packages: lowercase `snake_case` when multiple words are needed.
- Organize packages by domain model, not by technical type (no `controllers/`, `services/`, `models/` top-level split).
- Class names: singular nouns, PascalCase, must match filename. No numbers in class names.
- Avoid vague names: `Utils`, `Helpers`, `Manager`, `Constants`, `Entity`, `Object` without a bounded domain.
- Variables: `camelCase`, declare close to first use, delete unused.
- Use intuitive, specific names — avoid abstract (`result`, `data`, `temp`).
- Single-letter variables only for loop indices (`i`, `j`, `k`).
- Use meaningful names in lambda expressions.
- Collections: use plural nouns, avoid `List` prefix (`orders`, not `orderList`).
- Constants: `UPPER_SNAKE_CASE`. No magic numbers/strings — extract to named constants.
- Use underscores for readability in large numbers: `10_000_000`.
- No Hungarian notation. Don't use type names as variable names.
- Abbreviations allowed only if project-documented (e.g. MSISDN, BAN).

## Nullability

- Use JSpecify annotations for static null-safety analysis.
- Place `@NullMarked` at package level (`package-info.java`).
- Use `@Nullable` only for exceptions to the null-marked default.
- Use `@NotNull` only from `jakarta.validation.constraints` (for runtime validation).

## Class Structure

- Preferred line length: 90 characters (acceptable 90–120, hard limit 120).
- Separators (`,`, `+`, `?`, `:`, `&&`, `||`) stay at end of line when wrapping.
- Two blank lines before: static blocks, fields, constructors, inner classes.
- One blank line after multi-line method signatures.
- Recommended class element order:
  1. static fields → 2. final fields → 3. non-final fields
  4. constructors (most → least specialized) → 5. methods called from constructors
  6. static methods → 7. JavaBean properties → 8. interface implementations
  9. private/protected helpers → 10. `equals`, `hashCode`, `toString`
- Max 10 public methods per class. Max 15 lines for anonymous classes.
- Always use `this` for field access (except DI dependencies injected via constructor).
- Avoid package-private access — be explicit with visibility.
- No more than 3 levels of nesting for `if`/`for`/`while`/`switch`/`try`.
- Don't shadow parent class fields. Don't start threads in constructors.

## Methods

- Target 20–30 lines per method; 50 is a hard upper bound.
- Target up to 3 parameters; 4 only rarely. More → use a wrapper model.
- Remove unused private methods and their unused parameters.
- If a method mutates state, do not name it `check...` or `validate...`.
- Use predictable prefixes:
  - `find...` — search, returns `Optional` or `Collection`
  - `get...` — always returns value, throws if not found
  - `fetch...` — data from external source (REST API)
  - `build...` — constructs and returns an object
- Boolean methods as questions: `is...`, `has...`, `can...`.
- No numbers in method names. No abbreviations.
- Always add `@Override`.
- Use early return for validation checks.
- Mutating methods shouldn't return `Optional` — throw exception if needed.
- Don't use `Optional` as method parameter.
- Accept the most general type possible (`Collection` not `List`; `Iterable` not `ArrayList`).
- Return empty collections/arrays, not `null`.
- No `Stream` as parameter or return type (single-use only).
- Follow Single Responsibility Principle.

## Operators

- Replace multi-line string concatenation with text blocks.
- String literals LEFT-aligned in comparisons: `"VALUE".equals(input)`.
- Compare enums with `==`, not `equals()`.
- No nested ternary operators. Fallback value at the end of ternary.
- Don't invert boolean results — reverse the comparison instead.
- Max complexity of 3 for expressions using `&&`, `||`, ternary.
- Combine loops iterating the same collection.
- Max 5 lines per `switch` case — extract to methods.
- Never concatenate strings with `+` in loops — use `StringBuilder`.
- Max one `break`/`continue` per loop. Avoid labels.
- Use `try-with-resources` for all resources needing closure.
- Avoid nested `switch` statements.

## Standard Utilities

- Don't concatenate inside `StringBuilder.append()` — chain `.append()` calls.
- Use `EnumSet` instead of `HashSet` for enum values.
- Use `EnumMap` instead of `HashMap` for enum keys.
- Use `java.time` for dates/times, never `java.util.Date`.
- Prefer `valueOf()` over constructors for `String`, `BigInteger`, `BigDecimal`.
- Never use `new BigDecimal(double)` — use `new BigDecimal("...")` or `BigDecimal.valueOf()`.
- Replace lambda with method reference when possible.
- Don't use `var` for generics/collections where type is unclear.

## Exceptions

- Create domain-specific exceptions for business situations.
- Don't throw standard exceptions (`IllegalArgumentException`, etc.) for business logic.
- Always provide a message. Always preserve `cause` when wrapping.
- Exception should indicate whether stack trace should be printed for handler processing.
- Don't signal errors with `null`, `-1`, `UNKNOWN`, or caught `NullPointerException`.
- Don't catch `NullPointerException` — prevent it with proper checks.
- Public/external APIs: use checked exceptions, not `RuntimeException`.
- Combine catch blocks with identical handling (multi-catch).
- Avoid nested `try-catch`. Never catch `Throwable` or `Error`.
- Don't use flags or magic values for error signaling — use exceptions.

## Comments

- Explain "WHY", not "WHAT". Delete commented-out code (Git preserves history).
- Comment complex stream chains, calculations, and algorithms.
- Don't send messages to other developers in comments.
- Avoid TODO — use Jira instead. Exception: MVP phase only, remove after MVP.
- Avoid obvious comments that just describe what the code does.

## Lombok

- Use Lombok only when it reduces noise without hiding important behavior.
- Prefer `@RequiredArgsConstructor` for constructor injection.
- Use `@UtilityClass` for utility-only classes (generates private constructor, makes class final).
- When extending a parent class, explicitly add `@ToString(callSuper = true)` and `@EqualsAndHashCode(callSuper = true)`.
- If `@Data` is used, utilize its full capabilities.
- Use `@SuperBuilder` only if inheritance is truly required.
- Use `@FieldNameConstants` for type-safe field references (e.g. `@OneToMany.mappedBy`).
