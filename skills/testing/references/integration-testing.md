# Integration Testing Reference: Spring Boot Test + Testcontainers

## Choosing the Right Slice

| What to test | Annotation | Context |
|---|---|---|
| Controller + security + serialization | `@WebMvcTest(MyController.class)` | Only web layer |
| Repository + SQL queries | `@DataJpaTest` | JPA + DB only |
| Kafka consumers/producers | `@EmbeddedKafka` | Kafka in-memory |
| Full wiring, cross-layer | `@SpringBootTest` | Full context |

**Rule:** Never `@SpringBootTest` when a slice is enough. Slices start 5-10x faster.

---

## @WebMvcTest

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired MockMvc mvc;
    @MockBean  OrderService orderService;  // replaces real bean in context

    @Test
    void createOrder_shouldReturn201_whenValid() throws Exception {
        var request = new CreateOrderRequest(userId, items);
        when(orderService.create(any())).thenReturn(orderId);

        mvc.perform(post("/orders")
                .contentType(APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
            .andExpect(status().isCreated())
            .andExpect(header().string("Location", containsString("/orders/")));
    }

    @Test
    void createOrder_shouldReturn400_whenBodyMissing() throws Exception {
        mvc.perform(post("/orders").contentType(APPLICATION_JSON).content("{}"))
            .andExpect(status().isBadRequest());
    }
}
```

---

## @DataJpaTest + Testcontainers

Prefer real DB over H2 when:
- You use DB-specific features (Oracle sequences, PostgreSQL jsonb)
- Native queries use non-standard SQL

```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)  // disable embedded DB
@Testcontainers
class OrderRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres =
        new PostgreSQLContainer<>("postgres:15-alpine");

    @DynamicPropertySource
    static void configureDataSource(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired OrderRepository repo;

    @Test
    void findByStatus_shouldReturnOnlyMatching() {
        repo.save(pendingOrder());
        repo.save(completedOrder());

        var result = repo.findByStatus(PENDING);

        assertThat(result).hasSize(1)
                          .extracting(Order::status)
                          .containsOnly(PENDING);
    }
}
```

---

## @SpringBootTest

Use for cross-layer tests that validate real wiring:

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired TestRestTemplate restTemplate;

    @Test
    void fullOrderFlow_shouldPersistAndReturn() {
        var response = restTemplate.postForEntity("/orders", createRequest(), OrderResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
    }
}
```

---

## @MockBean vs @SpyBean

- `@MockBean` - replaces the real bean with a Mockito mock; you must stub everything.
- `@SpyBean` - wraps the real bean; only stubbed methods are replaced. Use when the real behavior is mostly correct but one external call needs to be overridden.
- Both cause Spring to rebuild the context -> prefer `@Mock` in unit tests to keep tests fast.

---

## Async Assertions with Awaitility

Never use `Thread.sleep`. Use Awaitility for async behavior:

```java
await().atMost(5, SECONDS)
       .pollInterval(100, MILLISECONDS)
       .untilAsserted(() ->
           assertThat(orderRepository.findByStatus(CONFIRMED)).hasSize(1)
       );
```

---

## Kafka Tests

```java
@SpringBootTest
@EmbeddedKafka(partitions = 1, topics = {"orders"})
class OrderKafkaConsumerTest {

    @Autowired EmbeddedKafkaBroker broker;
    @Autowired KafkaTemplate<String, OrderEvent> producer;

    @Test
    void consumer_shouldProcessOrderEvent() {
        producer.send("orders", new OrderEvent(orderId, CREATED));

        await().atMost(10, SECONDS).untilAsserted(() ->
            assertThat(processedOrders).contains(orderId)
        );
    }
}
```

---

## Shared Context: AbstractIntegrationTest

Avoid spinning up a new Spring context per test class:

```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
public abstract class AbstractIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15-alpine");

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }
}

class OrderIntegrationTest extends AbstractIntegrationTest { ... }
class PaymentIntegrationTest extends AbstractIntegrationTest { ... }
```

Spring reuses the same context if the configuration is identical.
