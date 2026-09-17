# Shared: карта затронутых слоёв

Переиспользуемый чек-лист для команд `/feature`, `/fix`, `/plan`, `/task`. Перечисли каждый слой,
который затронет изменение.

**Java/Spring:**
```text
- [ ] Controller / API
- [ ] Service / Domain
- [ ] Repository / Data access
- [ ] Configuration
- [ ] Messaging (Kafka)
- [ ] External integrations (REST)
- [ ] Tests (unit + integration)
- [ ] DB migration (Liquibase/Flyway)
```

**Go:**
```text
- [ ] Handler / Transport
- [ ] Service / Use cases
- [ ] Repository / Data access
- [ ] Configuration
- [ ] Middleware
- [ ] External integrations
- [ ] Tests
- [ ] DB migration
```

**Vue/Vite:**
```text
- [ ] Components (new / modified)
- [ ] Composables
- [ ] Pinia stores
- [ ] Router (new routes / guards)
- [ ] API layer (fetch/axios calls)
- [ ] Types / interfaces
- [ ] Tests (unit + component)
- [ ] Build / env config
```
