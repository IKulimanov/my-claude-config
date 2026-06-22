# Docker Local Dev Workflow

## Principles

- Local dev setup should start with a single command.
- Developers should not need to install databases or messaging manually.
- Source code changes should not require a full image rebuild during development.
- Secrets for local dev live in `.env.local` and are never committed.

## Typical Project Layout

```
project/
  docker-compose.yml          # base — infra only (db, kafka, redis)
  docker-compose.override.yml # local dev — app with bind mounts, debug ports
  .env.local                  # secrets and local overrides (gitignored)
  .env.example                # template with placeholder values (committed)
  Dockerfile                  # multi-stage: build + runtime
  .dockerignore
```

## Separating App from Infra in Compose

A common pattern: `docker-compose.yml` defines only infrastructure; the app is started separately (via IDE or `mvn spring-boot:run`).

```yaml
# docker-compose.yml — infra only
services:
  postgres:
    image: postgres:16-alpine
    ...

  kafka:
    image: confluentinc/cp-kafka:7.7.0
    ...
```

```yaml
# docker-compose.override.yml — app in container for full stack testing
services:
  app:
    build:
      context: .
      target: build        # stop at build stage for faster iteration
    volumes:
      - ./src:/app/src     # hot reload source
      - maven-cache:/root/.m2
    environment:
      SPRING_PROFILES_ACTIVE: local
    ports:
      - "8080:8080"
      - "5005:5005"        # remote debug port

volumes:
  maven-cache:
```

## Java Spring Boot Dev Container

For Spring Boot with DevTools / remote debug:

```yaml
services:
  app:
    build:
      context: .
      target: runtime
    environment:
      SPRING_PROFILES_ACTIVE: local
      JAVA_TOOL_OPTIONS: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    ports:
      - "8080:8080"
      - "5005:5005"
    volumes:
      - ./target:/app/target   # mount rebuilt jar for hot swap
```

Attach remote debugger in IntelliJ:
- Run → Edit Configurations → Remote JVM Debug → localhost:5005

## Go Dev Container

For Go with live reload using `air`:

```yaml
services:
  app:
    image: golang:1.23-alpine
    working_dir: /app
    command: sh -c "go install github.com/air-verse/air@latest && air"
    volumes:
      - .:/app
      - go-cache:/go/pkg/mod
    ports:
      - "8080:8080"
    environment:
      CGO_ENABLED: "0"

volumes:
  go-cache:
```

## Debugging Running Containers

```bash
# Get shell in running container
docker compose exec app sh

# Check logs with timestamps
docker compose logs --timestamps app

# Follow logs for multiple services
docker compose logs -f app postgres

# Inspect container environment
docker compose exec app env

# Check container resource usage
docker stats $(docker compose ps -q)

# Inspect a stopped container
docker run --rm -it --entrypoint sh my-service:local

# Copy files out of container
docker compose cp app:/app/logs/error.log ./error.log
```

## Debugging Network Issues

```bash
# Check if services can reach each other
docker compose exec app ping postgres

# Test HTTP from inside a container
docker compose exec app curl -s http://localhost:8080/actuator/health

# Inspect the Compose network
docker network inspect <project>_backend
```

## Cleaning Up

```bash
# Remove stopped containers
docker compose down

# Remove containers + volumes (WARNING: deletes DB data)
docker compose down -v

# Remove unused images
docker image prune

# Full cleanup (containers, networks, images, build cache)
docker system prune -a
```

## .env.local Template

Keep `.env.example` committed with placeholder values, `.env.local` gitignored:

```bash
# .env.example
DB_URL=jdbc:postgresql://localhost:5432/mydb
DB_USERNAME=myuser
DB_PASSWORD=changeme
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
```

```bash
# .gitignore
.env.local
.env
*.env
```

## Makefile Shortcuts (Optional)

A `Makefile` at the project root can simplify common tasks:

```makefile
.PHONY: up down logs build shell

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f

build:
	docker compose build --no-cache

shell:
	docker compose exec app sh

db-shell:
	docker compose exec postgres psql -U myuser -d mydb
```
