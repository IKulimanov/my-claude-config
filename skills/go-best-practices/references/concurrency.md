# Go Concurrency

## Context Propagation

- Every function that can block or make I/O calls takes `context.Context` as its first parameter.
- Use `context.WithTimeout` or `context.WithCancel` to bound goroutine lifetimes.
- Check `ctx.Err()` or `ctx.Done()` in long-running loops.

```go
func (s *Service) Process(ctx context.Context, id string) error {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()
    // ...
}
```

## Goroutine Lifecycle

Every goroutine must have:
1. A clear owner that starts it.
2. A shutdown signal (context cancellation, done channel, or WaitGroup).
3. Error propagation back to the owner.

### errgroup (preferred for fan-out)
```go
g, ctx := errgroup.WithContext(ctx)
for _, item := range items {
    g.Go(func() error {
        return process(ctx, item)
    })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("processing failed: %w", err)
}
```

### WaitGroup (when no error aggregation needed)
```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func() {
        defer wg.Done()
        handle(item)
    }()
}
wg.Wait()
```

## Channels

- Use channels for communication, mutexes for state protection.
- Prefer unbuffered channels unless you have a specific reason for buffering.
- Always close channels from the sender side, never from the receiver.
- Use `select` with `ctx.Done()` to avoid goroutine leaks.

```go
select {
case result := <-ch:
    // handle result
case <-ctx.Done():
    return ctx.Err()
}
```

## sync Primitives

| Primitive | Use when |
|-----------|----------|
| `sync.Mutex` | Protecting shared mutable state |
| `sync.RWMutex` | Many readers, few writers |
| `sync.Once` | One-time initialization |
| `sync.Map` | High-contention maps with disjoint key sets |
| `atomic` | Simple counters and flags |

## Anti-Patterns

- **Fire-and-forget goroutines** - always track goroutine lifecycle.
- **Shared memory without synchronization** - use mutexes or channels.
- **Unbounded goroutine spawning** - use a semaphore or worker pool.
- **Closing channels from receiver** - only the sender closes.
- **Goroutine leak** - every goroutine must have a cancellation path.
- **`time.Sleep` for synchronization** - use proper sync primitives.
