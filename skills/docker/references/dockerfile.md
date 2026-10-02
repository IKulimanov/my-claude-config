# Dockerfile Reference

## General Principles

- One concern per image - don't bundle unrelated services.
- Prefer official base images (`eclipse-temurin`, `golang`, `alpine`, `distroless`).
- Always pin image versions - avoid `latest` in Dockerfiles that go to CI or prod.
- Use `.dockerignore` to exclude `target/`, `build/`, `.git/`, `*.log`, local env files.

## Layer Caching

Order instructions from least to most frequently changed:

```dockerfile
# 1. Base image (rarely changes)
FROM eclipse-temurin:21-jre-alpine

# 2. System dependencies (infrequent)
RUN apk add --no-cache curl

# 3. Dependency manifest (changes less than source)
COPY pom.xml .
RUN mvn dependency:go-offline -q

# 4. Source code (changes most often)
COPY src ./src
RUN mvn package -DskipTests
```

## Multi-Stage Builds

Use multi-stage builds to keep the final image small:

### Java Service (Maven)

```dockerfile
# Stage 1: build
FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -q
COPY src ./src
RUN mvn package -DskipTests -q

# Stage 2: runtime
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build /app/target/*.jar app.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Go Service

```dockerfile
# Stage 1: build
FROM golang:1.23-alpine AS build
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o server ./cmd/server

# Stage 2: runtime (distroless for minimal attack surface)
FROM gcr.io/distroless/static-debian12 AS runtime
WORKDIR /app
COPY --from=build /app/server .
EXPOSE 8080
ENTRYPOINT ["/app/server"]
```

## Non-Root User

Always run as a non-root user in production images:

```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser
```

## Healthcheck

Add healthcheck for services that expose HTTP:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:8080/actuator/health || exit 1
```

## ENTRYPOINT vs CMD

- `ENTRYPOINT` - fixed executable, not overridable at runtime without `--entrypoint`
- `CMD` - default arguments, easily overridden at `docker run`
- Prefer exec form `["executable", "arg"]` over shell form `"executable arg"` - avoids PID 1 signal handling issues

```dockerfile
# Prefer this
ENTRYPOINT ["java", "-jar", "app.jar"]

# Over this
ENTRYPOINT java -jar app.jar
```

## JVM Tuning in Containers

For Java services, use container-aware JVM settings:

```dockerfile
ENTRYPOINT ["java", \
  "-XX:+UseContainerSupport", \
  "-XX:MaxRAMPercentage=75.0", \
  "-jar", "app.jar"]
```

Or via environment variable in Compose:

```yaml
environment:
  JAVA_OPTS: "-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
```

## Common Mistakes

- Copying `target/` or `build/` without `.dockerignore` - bloats context
- Running `apt-get update` without `--no-cache` in Alpine - causes layer bloat
- Forgetting to clean package manager caches in the same `RUN` layer
- Using `ADD` instead of `COPY` for local files - `ADD` has implicit tar extraction
- Setting `ENV` for secrets - they persist in image history; use `--secret` or runtime env instead
