# Docker Compose Reference

## File Layout Conventions

```
docker-compose.yml          # base definitions — used in all environments
docker-compose.override.yml # local dev overrides (auto-merged by Compose)
docker-compose.ci.yml       # CI-specific overrides
docker-compose.prod.yml     # prod-specific (usually minimal or absent)
```

Use `-f` to combine files explicitly, or let Compose auto-merge `override.yml`.

## Service Definition Skeleton

```yaml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: runtime       # reference a specific multi-stage target
    image: my-service:local
    container_name: my-service
    ports:
      - "8080:8080"
    environment:
      SPRING_PROFILES_ACTIVE: local
      DB_URL: jdbc:postgresql://db:5432/mydb
    env_file:
      - .env.local           # keep secrets out of compose files
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    networks:
      - backend
    volumes:
      - app-logs:/var/log/app

volumes:
  app-logs:

networks:
  backend:
    driver: bridge
```

## Dependencies and Health Checks

Use `condition: service_healthy` to wait for a dependency to be ready before starting:

```yaml
depends_on:
  postgres:
    condition: service_healthy
  kafka:
    condition: service_healthy
```

Never rely on `depends_on` alone without healthchecks — it only waits for container start, not readiness.

## Common Infrastructure Services

### PostgreSQL

```yaml
postgres:
  image: postgres:16-alpine
  container_name: postgres
  environment:
    POSTGRES_DB: mydb
    POSTGRES_USER: myuser
    POSTGRES_PASSWORD: mypassword
  ports:
    - "5432:5432"
  volumes:
    - postgres-data:/var/lib/postgresql/data
    - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U myuser -d mydb"]
    interval: 10s
    timeout: 5s
    retries: 5
```

### Kafka (with KRaft — no Zookeeper)

```yaml
kafka:
  image: confluentinc/cp-kafka:7.7.0
  container_name: kafka
  ports:
    - "9092:9092"
  environment:
    KAFKA_NODE_ID: 1
    KAFKA_PROCESS_ROLES: broker,controller
    KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
    KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
    KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
    KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
    KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    CLUSTER_ID: "MkU3OEVBNTcwNTJENDM2Qk"
  healthcheck:
    test: ["CMD", "kafka-broker-api-versions", "--bootstrap-server", "localhost:9092"]
    interval: 15s
    timeout: 10s
    retries: 5
```

### Redis

```yaml
redis:
  image: redis:7-alpine
  container_name: redis
  ports:
    - "6379:6379"
  command: redis-server --save 60 1 --loglevel warning
  volumes:
    - redis-data:/data
  healthcheck:
    test: ["CMD", "redis-cli", "ping"]
    interval: 10s
    timeout: 5s
    retries: 3
```

## Profiles

Use Compose profiles to enable optional services:

```yaml
services:
  app:
    # no profile — always started

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    profiles: [debug]
    depends_on: [kafka]
    ports:
      - "8090:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
```

Start with optional services:
```bash
docker compose --profile debug up
```

## Networking

- Services in the same Compose project reach each other by service name.
- `ports` exposes to the host; `expose` only opens between containers.
- Use separate networks to isolate service groups.

```yaml
networks:
  frontend:
  backend:

services:
  nginx:
    networks: [frontend, backend]
  app:
    networks: [backend]
  db:
    networks: [backend]
```

## Volumes

- Named volumes persist across `down`; anonymous volumes are removed on `down -v`.
- Use bind mounts for dev-time source code; use named volumes for data.

```yaml
volumes:
  postgres-data:        # named — persists
  redis-data:

services:
  app:
    volumes:
      - ./src:/app/src  # bind mount — live source reload in dev
      - app-logs:/var/log/app  # named volume for logs
```

## Secrets and Environment Variables

Never embed secrets in `docker-compose.yml`. Prefer:
1. `.env.local` loaded via `env_file` (not committed to git)
2. Docker secrets (`secrets:` top-level key) for Swarm mode
3. External secret managers (Vault, AWS Secrets Manager) injected at runtime

```yaml
services:
  app:
    env_file:
      - .env.local
```

`.gitignore` must include `.env.local`, `.env`, `.env.*`.

## Common Commands

```bash
# Start services
docker compose up -d

# Start with build
docker compose up -d --build

# Follow logs
docker compose logs -f app

# Execute into running container
docker compose exec app sh

# Run one-off command
docker compose run --rm app java -jar app.jar --migrate

# Stop and remove containers (keep volumes)
docker compose down

# Stop and remove containers AND volumes
docker compose down -v

# Rebuild a single service
docker compose build app

# Check service health
docker compose ps
```
