# Go Error Handling

## Core Rules

1. **Always check errors.** Never assign to `_` unless the function guarantees no meaningful failure.
2. **Wrap with context.** Use `fmt.Errorf("operation failed: %w", err)` to add context while preserving the original error.
3. **Return early.** Handle errors immediately, keep the happy path unindented.

```go
// Good
data, err := repo.Fetch(ctx, id)
if err != nil {
    return fmt.Errorf("fetch user %s: %w", id, err)
}
// use data...

// Bad — nested happy path
data, err := repo.Fetch(ctx, id)
if err == nil {
    // deep nesting...
}
```

## Error Types

### Sentinel Errors
Use for errors that callers must check by identity:
```go
var ErrNotFound = errors.New("not found")
var ErrConflict = errors.New("conflict")
```
Callers use `errors.Is(err, ErrNotFound)`.

### Custom Error Types
Use when callers need structured information:
```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s — %s", e.Field, e.Message)
}
```
Callers use `errors.As(err, &target)`.

### Wrapping
- Always wrap with `%w` when the caller should be able to unwrap.
- Use `%v` (not `%w`) when you intentionally want to hide the underlying error.

## Error Handling Patterns

### At Service Boundaries
Map internal errors to transport-appropriate responses:
```go
func mapError(err error) (int, string) {
    switch {
    case errors.Is(err, domain.ErrNotFound):
        return http.StatusNotFound, "resource not found"
    case errors.Is(err, domain.ErrConflict):
        return http.StatusConflict, "resource conflict"
    default:
        return http.StatusInternalServerError, "internal error"
    }
}
```

### Logging
- Log errors at the top level (handler or main loop), not at every layer.
- Include structured context: `slog.Error("failed to process order", "order_id", id, "error", err)`.
- Do not log and return the same error - choose one.

## Anti-Patterns

- `panic` for expected failures (use `return err`).
- Wrapping without new context: `fmt.Errorf("%w", err)` adds nothing.
- Strings matching: `strings.Contains(err.Error(), "not found")` - use sentinel errors.
- Swallowing errors in goroutines - always propagate via channels or `errgroup`.
