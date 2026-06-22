# Design Patterns in Java/Spring Context

## When to Apply Patterns

Patterns solve recurring design problems. Before introducing one:
1. Name the problem you are solving.
2. Confirm the pattern fits the problem (not the other way around).
3. Check if Spring already provides the abstraction.

---

## Strategy

**Problem:** Interchangeable algorithms or behaviors at runtime.
**Spring idiom:** Register `@Component`-annotated implementations, inject `List<Strategy>` or use a `Map<String, Strategy>`.

```java
public interface NotificationStrategy {
    void send(Notification n);
    NotificationType type();
}

@Service
public class NotificationDispatcher {
    private final Map<NotificationType, NotificationStrategy> strategies;

    public NotificationDispatcher(List<NotificationStrategy> strategyList) {
        this.strategies = strategyList.stream()
            .collect(toMap(NotificationStrategy::type, identity()));
    }
}
```

---

## Factory Method / Abstract Factory

**Problem:** Create objects without specifying the exact class.
**Spring idiom:** Usually a `@Bean` method is enough. Add a factory class only when the concrete type depends on runtime data.

```java
// Spring factory bean — sufficient for most cases
@Bean
public PaymentProcessor paymentProcessor(PaymentConfig config) {
    return config.provider() == STRIPE
        ? new StripePaymentProcessor(config)
        : new PaypalPaymentProcessor(config);
}
```

---

## Builder

**Problem:** Constructing objects with many optional fields.
**Java idiom:** Use Lombok `@Builder` or record with a manual builder. Avoid constructors with 4+ parameters.

- Use `@Builder` for immutable value objects and DTOs.
- Use `@Builder(toBuilder = true)` when you need to create modified copies.
- Validate required fields in `@Builder.Default` or a custom `build()` override.

---

## Decorator

**Problem:** Add responsibilities to an object without changing its class.
**Spring idiom:** Wrap a bean in another implementation of the same interface and qualify.

```java
@Primary
@Bean
public UserService cachingUserService(UserServiceImpl delegate, Cache cache) {
    return new CachingUserService(delegate, cache);
}
```

Also appears as: `HandlerInterceptor`, `Filter`, `WebMvcConfigurer`, Spring AOP.

---

## Template Method

**Problem:** Define a skeleton algorithm in a base class; subclasses fill in steps.
**Use when:** You have a stable process with variable steps.
**Avoid when:** The hierarchy would go deeper than 2 levels or the variation is better served by Strategy.

---

## Observer / Event

**Problem:** Decouple publisher from subscribers.
**Spring idiom:** Use `ApplicationEventPublisher` + `@EventListener`. Use `@TransactionalEventListener` when the handler should run after commit.

```java
// Publisher
eventPublisher.publishEvent(new OrderPlacedEvent(order));

// Listener
@EventListener
@Async
public void onOrderPlaced(OrderPlacedEvent event) { ... }
```

---

## Chain of Responsibility

**Problem:** Pass a request through a chain of handlers, each deciding to handle or pass on.
**Spring idiom:** `Filter` chain, `HandlerInterceptor`, or a custom `List<Handler>` with a loop.

---

## Proxy

**Problem:** Add cross-cutting concerns (caching, security, transactions) without modifying the target.
**Spring idiom:** Spring AOP — `@Transactional`, `@Cacheable`, `@Async`, `@PreAuthorize` are all proxies.

**Critical rule:** Spring proxies only intercept external calls to a bean. Self-invocation (calling `this.method()`) bypasses the proxy. Restructure or use `ApplicationContext.getBean(getClass())` as a last resort.

---

## Command Pattern

**Problem:** Encapsulate a request as an object for queueing, logging, or undo.
**Spring idiom:** Combine with `ApplicationEventPublisher` or a message queue (Kafka).

---

## Anti-patterns to Avoid

| Anti-pattern | Problem | Fix |
|---|---|---|
| Service Locator | Hidden dependencies, hard to test | Constructor injection |
| God Class | Everything in one class, low cohesion | Split by responsibility (SRP) |
| Anemic Domain | Business logic in services, entities are dumb DTOs | Move invariants to the domain object |
| Singleton via static | Global mutable state, untestable | Spring-managed singleton bean |
| Primitive Obsession | Passing `String`, `long` for domain concepts | Value objects (`UserId`, `Email`) |
