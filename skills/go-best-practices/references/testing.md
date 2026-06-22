# Go Testing

## Test File Conventions

- Test files: `*_test.go` in the same package (white-box) or `_test` package (black-box).
- Prefer black-box tests (`package foo_test`) for public API validation.
- Use white-box tests (`package foo`) only when internal state must be verified.

## Table-Driven Tests

The standard Go testing pattern:
```go
func TestParseAmount(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "valid integer", input: "100", want: 100},
        {name: "negative", input: "-50", want: -50},
        {name: "empty string", input: "", wantErr: true},
        {name: "overflow", input: "99999999999999999999", wantErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseAmount(tt.input)
            if tt.wantErr {
                require.Error(t, err)
                return
            }
            require.NoError(t, err)
            assert.Equal(t, tt.want, got)
        })
    }
}
```

## Assertions

Prefer `testify` for readable assertions:
```go
import (
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

// require — fails immediately (use for preconditions)
require.NoError(t, err)
require.NotNil(t, result)

// assert — continues on failure (use for multiple checks)
assert.Equal(t, expected, actual)
assert.Contains(t, slice, item)
assert.Empty(t, list)
```

## HTTP Handler Tests

Use `net/http/httptest`:
```go
func TestGetUser(t *testing.T) {
    svc := &mockUserService{user: testUser}
    handler := NewHandler(svc)

    req := httptest.NewRequest(http.MethodGet, "/users/123", nil)
    rec := httptest.NewRecorder()

    handler.ServeHTTP(rec, req)

    require.Equal(t, http.StatusOK, rec.Code)

    var got User
    require.NoError(t, json.NewDecoder(rec.Body).Decode(&got))
    assert.Equal(t, "123", got.ID)
}
```

## Database Tests

Use `testcontainers-go` for real DB tests:
```go
func setupPostgres(t *testing.T) *sql.DB {
    t.Helper()
    ctx := context.Background()

    container, err := postgres.Run(ctx, "postgres:16-alpine",
        postgres.WithDatabase("testdb"),
    )
    require.NoError(t, err)
    t.Cleanup(func() { container.Terminate(ctx) })

    connStr, err := container.ConnectionString(ctx, "sslmode=disable")
    require.NoError(t, err)

    db, err := sql.Open("pgx", connStr)
    require.NoError(t, err)
    return db
}
```

## Test Helpers

- Use `t.Helper()` in helper functions for correct line reporting.
- Use `t.Cleanup()` for teardown instead of `defer` (runs after test, not after helper).
- Use `t.TempDir()` for temporary files.
- Use `t.Parallel()` for independent tests, but avoid shared mutable state.

## Benchmarks

```go
func BenchmarkProcess(b *testing.B) {
    input := prepareInput()
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        Process(input)
    }
}
```

Run: `go test -bench=. -benchmem ./...`

## Mocking

- Define small interfaces at the consumer side.
- Implement mocks manually or use `mockgen` / `moq`.
- Prefer fakes (real in-memory implementations) over mocks for repositories.

## Anti-Patterns

- Testing private functions directly — test through the public API.
- `time.Sleep` in tests — use channels, tickers, or `assert.Eventually`.
- Giant test setup — extract helpers with `t.Helper()`.
- Shared mutable state across parallel tests.
- Ignoring `-race` flag — always run `go test -race ./...` in CI.
