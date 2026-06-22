# Go Project Structure

## Standard Layout

```
project/
  cmd/
    server/main.go          # entrypoint — thin, wires dependencies
    cli/main.go              # additional entrypoints if needed
  internal/
    domain/                  # core business types and logic (no external deps)
    service/                 # use cases, orchestration
    repository/              # data access (DB, cache, external APIs)
    handler/                 # HTTP/gRPC handlers (transport layer)
    config/                  # configuration loading
  pkg/                       # public reusable packages (use sparingly)
  migrations/                # SQL migrations (goose, migrate, atlas)
  api/                       # OpenAPI specs, proto files
  deploy/                    # Dockerfile, k8s manifests, Helm charts
  go.mod
  go.sum
  Makefile
```

## Key Principles

### Package Design
- Package names are short, lowercase, singular: `user`, `order`, `auth` — not `users`, `models`, `utils`.
- A package exposes a cohesive API. If two types are always used together, they belong in the same package.
- Avoid `common`, `utils`, `helpers`, `shared` — they become dumping grounds.
- `internal/` prevents external imports — use it for everything that is not a public API.

### Dependency Direction
```
cmd/ → internal/service → internal/domain
                        → internal/repository
internal/handler → internal/service
```
- Domain types have zero external dependencies.
- Repository implements interfaces defined in the service or domain layer.
- Handlers depend on services, never on repositories directly.

### Configuration
- Use environment variables as the primary config source (12-factor).
- Parse config once at startup into a typed struct.
- Prefer `envconfig`, `viper`, or plain `os.Getenv` with validation.
- Never read env vars deep in business logic.

### Dependency Injection
- Wire dependencies manually in `main()` or use `fx`/`wire` for large services.
- Prefer constructor functions: `func NewUserService(repo UserRepo, log *slog.Logger) *UserService`.
- Accept interfaces, return structs.

## Module Management

- Run `go mod tidy` after adding/removing imports.
- Pin direct dependencies; let Go manage transitive ones.
- Use `go mod vendor` only when required by CI or air-gapped environments.
- Prefer tagged releases when importing third-party modules.
