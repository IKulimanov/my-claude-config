# SOLID and Clean Code in Java

## SOLID

### Single Responsibility Principle (SRP)
A class should have one reason to change.

**Signs of violation:** class name contains `And`, `Or`, `Manager`, `Util`; class has 500+ lines; it talks to the DB AND sends emails AND formats output.

**Fix:** Extract focused collaborators. In Spring, one service per aggregate or use case.

### Open/Closed Principle (OCP)
Open for extension, closed for modification.

**Java idiom:** Use polymorphism and Strategy instead of `instanceof` + `if/else` chains that grow with every new type.

```java
// Closed for modification — add new type by implementing interface
public interface DiscountPolicy {
    Money calculate(Order order);
}
```

### Liskov Substitution Principle (LSP)
Subclasses must be substitutable for their base class without breaking correctness.

**Signs of violation:** subclass throws `UnsupportedOperationException`; subclass narrows preconditions; overridden method ignores required parent behavior.

**Fix:** Prefer composition over inheritance. Use interfaces when you need polymorphism without a behavioral contract.

### Interface Segregation Principle (ISP)
Clients should not depend on interfaces they do not use.

**Java idiom:** Small, focused interfaces. In Spring, a repository interface should not force all clients to depend on admin operations.

```java
// Segregated
public interface OrderReader { Order findById(Long id); }
public interface OrderWriter { Order save(Order order); }
public interface OrderRepository extends OrderReader, OrderWriter {}
```

### Dependency Inversion Principle (DIP)
High-level modules should depend on abstractions, not concretions.

**Spring idiom:** This is enforced naturally by constructor injection + interface types. If you find yourself injecting `UserServiceImpl` instead of `UserService`, that is a DIP violation.

---

## Clean Code in Java

### Naming

- Class names: nouns that describe a concept, not a vague role (`UserService`, not `UserHelper`).
- Method names: verbs or verb phrases (`findUserById`, `calculateDiscount`).
- Variable names: pronounceable, intent-revealing (`customerOrders`, not `co` or `list1`).
- Constants: `SCREAMING_SNAKE_CASE`; define where they are used, not in a global `Constants` class.

### Method Design

- One level of abstraction per method.
- No more than 3 parameters; group related params into an object.
- Boolean parameters usually signal a method doing two things — split it.
- Side-effecting methods should not also return a value (Command/Query Separation).

### Avoiding Common Pitfalls

```java
// Bad: leaking implementation detail
public ArrayList<User> getUsers() { ... }

// Good: program to interface
public List<User> getUsers() { ... }

// Bad: null as "not found"
public User findById(Long id) { return null; }  // caller will forget to check

// Good: explicit absence
public Optional<User> findById(Long id) { ... }

// Bad: checked exception for flow control
try { parse(input); } catch (ParseException e) { return DEFAULT; }

// Good: use Optional or a Result type for expected failures
Optional<ParsedValue> parse(String input) { ... }
```

### Optional Idioms

```java
// Return Optional from queries
Optional<User> findByEmail(String email);

// Chain, do not call .get() eagerly
userRepository.findByEmail(email)
    .map(User::getProfile)
    .orElseThrow(() -> new UserNotFoundException(email));

// Do NOT use Optional as a field or parameter
// Bad: Optional<String> name field
// Bad: void process(Optional<Input> input)
```

### Stream API

```java
// Use for transformation pipelines — keep them short
List<String> names = users.stream()
    .filter(User::isActive)
    .map(User::getFullName)
    .sorted()
    .toList();

// Do not use streams for side effects
users.stream().forEach(repo::save);  // use a plain for loop instead

// Do not chain 10 operations in one stream — extract intermediates
```

### Immutability

- Prefer immutable value objects (records in Java 16+) for DTOs, events, and domain values.
- Use `List.copyOf()` / `Map.copyOf()` when exposing collections.
- Never return internal mutable collections directly.

```java
// Good: record as immutable DTO
public record CreateOrderRequest(
    @NotNull UserId userId,
    @NotEmpty List<OrderItem> items
) {}
```
