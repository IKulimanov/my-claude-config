# Unit Testing Reference: JUnit 5 + Mockito + AssertJ

## Team Unit Test Standard

Write tests that describe system behavior — not implementation details.

### Checklist for Every Test

1. Does the test verify a business rule or just implementation details?
2. Can one stronger assert replace multiple weak ones?
3. Is there arrange-part duplication that should be extracted?
4. Does the name clearly state what the test guarantees?
5. Is this really a unit test, or did Spring context leak in?
6. Will the test break only when a real contract changes?
7. Does the test have one clear business assertion?

### Naming Convention

Pattern: `methodName_shouldExpectedBehavior_whenCondition`
If condition is not important: `methodName_shouldExpectedBehavior`

```java
void supportedFormats_shouldReturnExactSupportedFormats()
void render_shouldThrowException_whenTemplateIsMissing()
void calculate_shouldApplyDiscount_forVipCustomer()
```

### What Makes a Good Test

- Verifies the external contract, not internal implementation.
- Has one clear business assertion.
- Reads like a behavior specification.
- Contains no redundant asserts already covered by a stronger check.
- Doesn't duplicate data preparation without reason.
- Breaks only when important behavior actually changes.

### What Is Considered Bad Style

- `@SpringBootTest` in a plain unit test.
- Testing private/internal details instead of the result.
- Many small tests for the same contract when one precise assert covers it.
- Redundant `isNotNull()` / `isNotEmpty()` before `containsExactly()`, `isEqualTo()`, `hasSize()`.
- Large duplication of arrange-part across tests.
- Vague names: `test1()`, `check()`, `shouldWork()`.

---

## JUnit 5 Essentials

### Test Lifecycle

```java
@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock  PaymentGateway gateway;
    @Mock  PaymentRepository repo;
    @InjectMocks  PaymentService service;

    @BeforeEach
    void setUp() {
        // runs before each @Test
    }
}
```

### Parameterized Tests

```java
@ParameterizedTest
@ValueSource(strings = { "", "   ", "\t" })
void validate_shouldReject_whenBlank(String value) {
    assertThatThrownBy(() -> validator.validate(value))
        .isInstanceOf(ValidationException.class);
}

@ParameterizedTest
@MethodSource("provideInvalidAmounts")
void calculate_shouldReject_whenAmountInvalid(BigDecimal amount, String expectedMessage) {
    assertThatThrownBy(() -> service.calculate(amount))
        .hasMessageContaining(expectedMessage);
}

static Stream<Arguments> provideInvalidAmounts() {
    return Stream.of(
        Arguments.of(BigDecimal.ZERO, "must be positive"),
        Arguments.of(BigDecimal.valueOf(-1), "must be positive")
    );
}
```

### Nested Tests for Context Grouping

```java
@Nested
class WhenUserIsActive {
    @BeforeEach void setUp() { user = activeUser(); }

    @Test void should_allowPayment() { ... }
    @Test void should_sendConfirmation() { ... }
}

@Nested
class WhenUserIsBlocked {
    @BeforeEach void setUp() { user = blockedUser(); }

    @Test void should_rejectPayment() { ... }
}
```

---

## Mockito

### Basic Stubbing

```java
when(gateway.charge(any())).thenReturn(PaymentResult.success("txn-123"));
when(gateway.charge(any())).thenThrow(new GatewayException("Timeout"));
when(repo.save(any())).thenAnswer(inv -> inv.getArgument(0));
```

### Verification

```java
verify(gateway, times(1)).charge(any());
verify(gateway, never()).refund(any());

ArgumentCaptor<ChargeRequest> captor = ArgumentCaptor.forClass(ChargeRequest.class);
verify(gateway).charge(captor.capture());
assertThat(captor.getValue().amount()).isEqualByComparingTo("99.99");
```

### Spy

```java
PaymentService spy = Mockito.spy(new PaymentService(realGateway));
doReturn(false).when(spy).isFeatureEnabled("new-flow");
```

---

## AssertJ Best Patterns

### Prefer Strong Asserts Over Multiple Weak Ones

```java
// BAD: redundant checks
assertThat(result).isNotNull();
assertThat(result.getItems()).isNotEmpty();
assertThat(result.getItems()).hasSize(3);

// GOOD: one strong assert covers all
assertThat(result.getItems()).hasSize(3);
```

### Pattern Reference

| Scenario | Best Pattern |
|---|---|
| Collection exact content | `assertThat(values).containsExactlyInAnyOrder(A, B)` |
| Exception | `assertThatThrownBy(() -> service.run()).isInstanceOf(...)` |
| No exception | `assertThatNoException().isThrownBy(() -> service.validate(input))` |
| DTO / object | `assertThat(actual).usingRecursiveComparison().isEqualTo(expected)` |
| Object fields | `assertThat(order).extracting(Order::status, Order::total).containsExactly(PENDING, TEN)` |
| List of objects | `assertThat(users).extracting(User::getName).contains("Ivan")` |
| BigDecimal | `assertThat(amount).isEqualByComparingTo("10.00")` |
| Optional | `assertThat(optional).isPresent().hasValue("expected")` |

### Soft Assertions (Don't Stop at First Failure)

```java
SoftAssertions.assertSoftly(soft -> {
    soft.assertThat(result.status()).isEqualTo(SUCCESS);
    soft.assertThat(result.transactionId()).isNotNull();
    soft.assertThat(result.amount()).isEqualByComparingTo("100.00");
});
```

---

## When @SpringBootTest Is Needed vs Not

| Scenario | Use |
|---|---|
| Pure logic, mapper, validator, util, policy, calculator, strategy | JUnit 5 + Mockito (NO Spring) |
| Controller + serialization + security | `@WebMvcTest` |
| Repository + SQL queries | `@DataJpaTest` + Testcontainers |
| Full wiring, cross-layer integration | `@SpringBootTest` |

**Most often `@SpringBootTest` can be replaced with Mockito + plain unit test.**

---

## Test Data Builders

Avoid scattered construction — use dedicated builder or mother object:

```java
public class OrderTestData {
    public static Order pendingOrder() {
        return Order.builder()
            .id(OrderId.of(1L))
            .userId(UserId.of(42L))
            .status(PENDING)
            .items(List.of(orderItem()))
            .build();
    }
}
```

---

## Mini-Standard (Keep In Mind)

- Write tests that describe system behavior.
- Use JUnit 5 as framework, AssertJ as assertion language.
- One test = one clear contract.
- Less noise and duplication = higher test value.
