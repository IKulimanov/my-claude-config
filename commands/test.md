---
description: Write tests for a specified class or method. Auto-detects the stack, chooses the correct test layer, and delegates to the appropriate test-writer agent.
argument-hint: <class/method/file to cover with tests>
allowed-tools: Read, Edit, Write, Grep, Glob, Bash, Agent
---

# Test

Написать тесты для указанного класса, метода или модуля.

## Порядок работы

### Шаг 1 — Определить стек и загрузить контекст

1. Прочитай локальный `CLAUDE.md`.
2. Определи стек и делегируй:
   - **Java/Spring**: загрузи скил `testing` → делегируй агенту `test-writer`.
   - **Go**: загрузи `go-best-practices/references/testing.md` → делегируй агенту `go-test-writer`.
   - **Vue/JS**: загрузи `vue-frontend/references/testing-vue.md` → делегируй агенту `vue-test-writer`.

### Шаг 2 — Разобрать цель

1. Прочитай класс/метод/модуль, который покрываешь.
2. Посмотри существующие тесты, чтобы совпасть с их именованием и стилем.
3. Выбери правильный уровень теста:

**Java:**
| Что покрываем | Уровень |
|---|---|
| Чистая логика, без Spring | Unit: JUnit 5 + Mockito |
| Контроллер + сериализация | `@WebMvcTest` |
| Репозиторий + SQL | `@DataJpaTest` + Testcontainers |
| Kafka consumer/producer | `@EmbeddedKafka` или Testcontainers |
| Связка нескольких слоёв | `@SpringBootTest` |

**Vue:**
| Что покрываем | Уровень |
|---|---|
| Composable / утилита | Unit-тест на Vitest |
| Рендер компонента + события | Vue Test Utils + mount |
| Логика стора | Pinia testing utils |

**Go:**
| Что покрываем | Уровень |
|---|---|
| Чистая функция | Табличный unit-тест |
| HTTP-обработчик | httptest |
| Работа с БД | Testcontainers |

### Шаг 3 — Написать тесты

1. Покрой: happy path, краевые случаи, случаи ошибок.
2. Соблюдай командное именование: `methodName_shouldBehavior_whenCondition`.
3. Используй сильные проверки (AssertJ для Java, expect для JS, testify для Go).
4. Один тест — один понятный бизнес-контракт.
5. Чек-лист из 7 пунктов («Team Test Standard») применяет агент `test-writer` — он описан в самом
   агенте, а не в скиле `testing`. Для других стеков это профильный test-writer: `go-test-writer`,
   `vue-test-writer`.

### Шаг 4 — Отчитаться

```text
## Написаны тесты: <цель>

### Уровень
<выбранный уровень и почему>

### Покрытие
- <сценарий 1>
- <сценарий 2>
- ...

### Что не покрыто
- <что осознанно оставлено и почему>

### Проверка
- <команда запуска тестов> — <результат>
```
