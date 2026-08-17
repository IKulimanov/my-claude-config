# Конвенция: выжимка Sonar-правил (LANG / SPR / DB)

> Сгенерировано `scripts/gen-convention-checklist.sh` из `convention-sonar-rules-plugin`.
> **ВНУТРЕННЕЕ — не публиковать** в открытый доступ. Это командная конвенция nurtelecom.
> Набор совпадает с правилами CI Sonar (`mvn verify sonar:sonar`). Правил: 27.
> Обновить после изменения правил плагина: `scripts/gen-convention-checklist.sh`.

Как пользоваться: при написании и проверке Java-кода сверяйся по кодам (LANG-/SPR-/DB-).
Локальная проверка — предфильтр; финальный вердикт даёт CI Sonar.

## Быстрый чек-лист

| Код | Правило |
|-----|---------|
| DB-002 | Названия таблиц должны быть существительными во множественном… |
| LANG-103 | Не использовать разные названия в имени класса и в имени файла. |
| LANG-109 | Не использовать цифры в именах классов. |
| LANG-113 | Порядок геттеров/сеттеров (при их наличии) должен совпадать с… |
| LANG-115 | Обращение к полю уровня класса всегда должно осуществляться с… |
| LANG-116 | Не рекомендуется использовать package-private (дефолтный) уровень… |
| LANG-201 | Переменные должны именоваться в camelCase стиле. |
| LANG-206 | Не использовать цифры в именах переменных. |
| LANG-208 | Переменные из одной буквы могут быть только i, j, k и могут… |
| LANG-210 | Старайтесь не использовать имена переменных совпадающие с… |
| LANG-211 | Не следует использовать венгерскую нотацию - стиль именования… |
| LANG-212 | Не рекомендуется использовать название типа коллекции (List, Set и… |
| LANG-214 | При объявлении констант использовать UPPER_SNAKE_CASE. |
| LANG-215 | Не использовать вывод типа var для коллекций или других… |
| LANG-223 | Nullability-аннотации должны иметь однозначную семантику по всему… |
| LANG-409 | Не использовать цифры в именах методов. |
| LANG-410 | Максимальное количество параметров метода, к которому нужно… |
| LANG-503 | Любое исключение не должно быть использовано без указания message. |
| SPR-005 | В случаях, когда сами задаем bean-name или qualifier в Spring аннотациях, это… |
| SPR-006 | Рекомендуется именовать метод, аннотированный @PostConstruct, полным… |
| SPR-009 | Рекомендуется использовать @RequiredArgsConstructor из Lombok для бина в… |
| SPR-104 | В Spring Data репозиториях названия параметров в @Param при нативных… |
| SPR-105 | Не рекомендуется работать с jpa-энтити вне сервисов, которые… |
| SPR-106 | С энтити мы работаем только в "доменных" сервисах, а в остальных… |
| SPR-109 | При работе с нативными запросами и использовании RowMapper-ов… |
| SPR-302 | Периодичность/крон-выражение выполнения джоба обязательно… |
| SPR-902 | Не следует использовать конкатенацию строк для формирования… |

## Детали с примерами

### DB-002

Названия таблиц должны быть существительными во множественном числе, отражающими сущность, которую они представляют. Множественное число естественно отражает, что таблица содержит коллекцию записей. Соответствует общепринятым соглашениям об именовании в реляционных базах данных.

Неправильно:
```java
@Table(name = "auth_user")
public class AuthUserEntity { ... }
```
Правильно:
```java
@Table(name = "auth_users")
public class AuthUserEntity { ... }
```

### LANG-103

Не использовать разные названия в имени класса и в имени файла. Соответствие имени файла и класса является стандартом Java и упрощает поиск файлов. Предотвращает путаницу при работе с файловой системой и IDE.

Неправильно:
```java
// Файл: SubscriberService.java
public class SubscriberManager {
}
```
Правильно:
```java
// Файл: SubscriberService.java
public class SubscriberService {
}
```

### LANG-109

Не использовать цифры в именах классов. Имена с цифрами обычно указывают на плохую структуру кода или отсутствие осмысленных названий. Ухудшают читаемость и не соответствуют общепринятым соглашениям об именовании. Могут создавать проблемы при работе с некоторыми инструментами и системами.

Неправильно:
```java
public class SubscriberService2 {
}
```
Правильно:
```java
public class SubscriberService {
}
public class ApiV2Client {
}
public class IpV4AddressParser {
}
```

### LANG-113

Порядок геттеров/сеттеров (при их наличии) должен совпадать с порядком объявления связанных с ними полей. Соответствие порядка упрощает поиск методов для конкретного поля. Создает предсказуемую структуру класса и улучшает его читаемость. Упрощает навигацию по коду, особенно в классах с большим количеством свойств.

Неправильно:
```java
public class Subscriber {
    private String name;
    private String phone;
    public String getPhone() {
        return phone;
    }
    public String getName() {
        return name;
    }
}
```
Правильно:
```java
public class Subscriber {
    private String name;
    private String phone;
    public String getName() {
        return name;
    }
    public String getPhone() {
        return phone;
    }
}
```

### LANG-115

Обращение к полю уровня класса всегда должно осуществляться с помощью this. Явное указание this устраняет неоднозначность между полями класса и локальными переменными. Улучшает читаемость кода и делает намерение разработчика более понятным. Предотвращает случайное затенение полей локальными переменными с теми же именами. Исключения сделаны для Spring-bean/repository полей и для зависимостей, распознанных как DI-поля (например, через field injection, явный constructor injection или Lombok @RequiredArgsConstructor в Spring-бине). Обычные value-поля вроде Integer или String не считаются зависимостями только из-за участия в конструкторе или @RequiredArgsConstructor и по-прежнему должны читаться через this.

Неправильно:
```java
public class SubscriberService {
    private String status;
    public void markActive() {
        status = "ACTIVE";
    }
}
```
Правильно:
```java
public class SubscriberService {
    private String status;
    public void markActive() {
        this.status = "ACTIVE";
    }
}
```

### LANG-116

Не рекомендуется использовать package-private (дефолтный) уровень доступа для полей класса. Предпочтительнее явно указывать уровень доступа, чтобы избежать непредвиденных изменений. Явное указание уровня доступа делает намерения разработчика понятными и предотвращает случайные изменения. Package-private доступ может привести к нежелательной связанности между классами в одном пакете. Улучшает инкапсуляцию и делает код более безопасным и предсказуемым.

Неправильно:
```java
public class SubscriberService {
    String status;
}
```
Правильно:
```java
public class SubscriberService {
    private String status;
}
```

### LANG-201

Переменные должны именоваться в camelCase стиле. Обеспечивает единообразие кода и упрощает его чтение.

Неправильно:
```java
String My_Variable = "value";
String SOME_VALUE = "value";
String MyVariable = "value";
```
Правильно:
```java
String myVariable = "value";
String someValue = "value";
```

### LANG-206

Не использовать цифры в именах переменных. Имена с цифрами обычно указывают на плохую структуру кода или отсутствие осмысленных названий.

Неправильно:
```java
String value1 = "first";
String value2 = "second";
int count3 = 0;
```
Правильно:
```java
String firstValue = "first";
String secondValue = "second";
int totalCount = 0;
String apiV2Client = "ok";
String ipV4Address = "ok";
```

### LANG-208

Переменные из одной буквы могут быть только i, j, k и могут использоваться только в качестве счетчиков циклов, где их назначение очевидно из контекста. Предотвращает использование неоднозначных однобуквенных переменных в других контекстах.

Неправильно:
```java
String s = "value";
int x = 10;
int i = 0; // вне цикла
```
Правильно:
```java
String status = "value";
int count = 10;
for (int i = 0; i &lt; 10; i++) {
    // i допустим как счётчик цикла
}
```

### LANG-210

Старайтесь не использовать имена переменных совпадающие с именами типов (как часто предлагает IDE). Имена, совпадающие с типами, не передают семантику переменной и ее роль в контексте. Ухудшают читаемость кода, так как не добавляют информации о назначении переменной.

Неправильно:
```java
UserEntity userEntity = userService.findUserByName(session.getUserName());
```
Правильно:
```java
UserEntity currentUser = userService.findUserByName(session.getUserName());
// или если в этом же методе так же используется модель текущего пользователя
UserEntity currentUserEntity = userService.findUserByName(session.getUserName());
```

### LANG-211

Не следует использовать венгерскую нотацию - стиль именования переменных, при котором к имени переменной добавляется префикс, указывающий на её тип, семантику или категорию данных. Венгерская нотация избыточна в языках со статической типизацией, где тип известен из объявления. Префиксы усложняют рефакторинг при изменении типа переменной.

Неправильно:
```java
String strName = "John Doe";
int iAge = 30;
boolean bIsActive = true;
List&lt;String&gt; lstItems = new ArrayList&lt;&gt;();
```
Правильно:
```java
String subscriberFullName = "John Doe";
int subscriberAge = 30;
boolean isSubscriberActive = true;
List&lt;String&gt; items = new ArrayList&lt;&gt;();
```

### LANG-212

Не рекомендуется использовать название типа коллекции (List, Set и др.) в названии переменных. Лучше использовать множественное число. Множественное число естественно передает, что переменная содержит коллекцию элементов. Избегает избыточности, так как тип коллекции уже указан в объявлении переменной.

Неправильно:
```java
List&lt;Subscriber&gt; subscriberList = subscriberService.findAll();
List&lt;PricePlan&gt; pricePlanList = pricePlanRepository.getActivePricePlans();
```
Правильно:
```java
List&lt;Subscriber&gt; subscribers = subscriberService.findAll();
List&lt;PricePlan&gt; pricePlans = pricePlanRepository.getActivePricePlans();
```

### LANG-214

При объявлении констант использовать UPPER_SNAKE_CASE. Каждая константа является static final полем, но не все static final поля являются константами. Поэтому UPPER_SNAKE_CASE следует выбирать только в том случае, если поле действительно является константой. UPPER_SNAKE_CASE является стандартом Java для именования констант и обеспечивает их визуальное выделение. Позволяет быстро отличить константы от обычных переменных при чтении кода.

Неправильно:
```java
// Константы — должны быть в UPPER_SNAKE_CASE
private static final Object nullHolder = new NullHolder();
public static final int defaultPort = -1;
```
Правильно:
```java
// Константы
private static final Object NULL_HOLDER = new NullHolder();
public static final int DEFAULT_PORT = -1;
// НЕ константы (параметризованные типы — исключение)
private static final ThreadLocal&lt;Executor&gt; executorHolder = new ThreadLocal&lt;Executor&gt;();
private static final Set&lt;String&gt; internalAnyAttributes = new HashSet&lt;String&gt;();
```

### LANG-215

Не использовать вывод типа var для коллекций или других дженериков. В остальных случаях использование var допустимо и остается на усмотрение разработчика, но не должно ухудшать читаемость кода. На данный момент использование var для дженериков не дает в IDE возможности быстрого перехода к типу переменной.

Неправильно:
```java
var subscribers = subscriberService.findAll();
var pricePlans = new HashMap&lt;String, PricePlan&gt;();
var callHistory = new ArrayList&lt;CallRecord&gt;();
```
Правильно:
```java
List&lt;Subscriber&gt; subscribers = subscriberService.findAll();
Map&lt;String, PricePlan&gt; pricePlans = new HashMap&lt;&gt;();
List&lt;CallRecord&gt; callHistory = new ArrayList&lt;&gt;();
// var допустим для не-дженериков
var subscriberService = new SubscriberService();
var phoneNumber = "+79001234567";
```

### LANG-223

Nullability-аннотации должны иметь однозначную семантику по всему проекту. Для статического анализа nullness-контрактов используйте org.jspecify.annotations.NonNull вместе с org.jspecify.annotations.NullMarked там, где это уместно. Аннотация @NotNull должна использоваться только как jakarta.validation.constraints.NotNull, то есть как runtime-валидационное ограничение. Смешивание разных @NonNull/@NotNull аннотаций размывает смысл кода: становится непонятно, это контракт для статического анализа или constraint для bean validation.

Неправильно:
```java
import lombok.NonNull;
import org.jetbrains.annotations.NotNull;
class UserService {
    @NotNull
    String loadName(@NonNull String userId) {
        return userId;
    }
}
```
Правильно:
```java
import jakarta.validation.constraints.NotNull;
import org.jspecify.annotations.NonNull;
class UserService {
    @NotNull
    String loadName(@NonNull String userId) {
        return userId;
    }
}
```

### LANG-409

Не использовать цифры в именах методов. Имена с цифрами обычно указывают на плохую структуру кода или отсутствие осмысленных названий. Ухудшают читаемость и не соответствуют общепринятым соглашениям об именовании. Исключением могут быть случаи, когда цифры являются неотъемлемой частью доменной терминологии или общепринятыми обозначениями (например, HTTP/2, OAuth2 и т.д.).

Неправильно:
```java
public void process2() { }
public String getValue1() { return ""; }
```
Правильно:
```java
public void process() { }
public String getValue() { return ""; }
// Исключения — доменная терминология
public void connectApiV2() { }
public String parseIpV4Address() { }
```

### LANG-410

Максимальное количество параметров метода, к которому нужно стремиться — 3. В редких случаях допускается 4 параметра, но не более. В остальных случаях рекомендуется использовать модель-обертку, которая будет содержать все необходимые параметры. Снижение когнитивной нагрузки — легче понять метод и его контракт, когда входных значений немного. Минимизация ошибок при вызове метода — меньше шансов перепутать порядок параметров. Упрощение и инкапсуляция валидации входящих данных через @Valid-аннотации. Гибкость при добавлении новых параметров в будущем без изменения сигнатуры метода.

Неправильно:
```java
public void processPayment(String accountId, BigDecimal amount, String currency, LocalDate paymentDate, String paymentDescription) {
    // какой-то процесс
}
```
Правильно:
```java
public class PaymentRequest {
    private String accountId;
    private BigDecimal amount;
    private String currency;
    private LocalDate paymentDate;
    private String paymentDescription;
}
public void processPayment(PaymentRequest paymentRequest) {
    // какой-то процесс
}
```

### LANG-503

Любое исключение не должно быть использовано без указания message. Сообщение об ошибке критично для понимания причины исключения и отладки. Улучшает логирование и мониторинг приложения, позволяя быстро идентифицировать проблемы.

Неправильно:
```java
throw new RuntimeException();
throw new IllegalArgumentException(cause);
```
Правильно:
```java
throw new RuntimeException("Something went wrong");
throw new IllegalArgumentException("Invalid argument", cause);
```

### SPR-005

В случаях, когда сами задаем bean-name или qualifier в Spring аннотациях, это название необходимо выносить в константы. А из других сервисов при внедрении зависимости использовать эти же константы. Использование констант предотвращает ошибки из-за опечаток в строках. Упрощает поиск бинов, которые используют конкретный qualifier. Упрощает рефакторинг, так как изменения нужно делать только в одном месте.

Неправильно:
```java
@Bean("myCustomBean")
public MyService myService() { ... }
@Qualifier("myCustomBean")
private MyService myService;
@Service("myService")
public class MyServiceImpl { ... }
```
Правильно:
```java
public static final String MY_CUSTOM_BEAN = "myCustomBean";
@Bean(MY_CUSTOM_BEAN)
public MyService myService() { ... }
@Qualifier(MY_CUSTOM_BEAN)
private MyService myService;
@Service(MY_CUSTOM_BEAN)
public class MyServiceImpl { ... }
```

### SPR-006

Рекомендуется именовать метод, аннотированный @PostConstruct, полным названием initialize(). Единообразное именование "служебных" методов не противоречит общим рекомендациям по стилю кода. Минимизирует возможные конфликты с методами init() в старых версиях Spring.

Неправильно:
```java
@PostConstruct
public void init() {
    // ...
}
```
Правильно:
```java
@PostConstruct
public void initialize() {
    // ...
}
```

### SPR-009

Рекомендуется использовать @RequiredArgsConstructor из Lombok для бина в случаях, если конструктор бина используется только для внедрения зависимостей, и в нем не выполняется какая-либо логика, или вызов конструктора супер-класса. @RequiredArgsConstructor автоматически генерирует конструктор, уменьшая шаблонный код. Упрощает поддержку кода и снижает вероятность ошибок при добавлении новых зависимостей.

Неправильно:
```java
@Service
public class SubscriberService {
    private final SubscriberRepository subscriberRepository;
    private final PricePlanRepository pricePlanRepository;
    private final NotificationService notificationService;
    public SubscriberService(SubscriberRepository subscriberRepository,
                            PricePlanRepository pricePlanRepository,
                            NotificationService notificationService) {
        this.subscriberRepository = subscriberRepository;
        this.pricePlanRepository = pricePlanRepository;
        this.notificationService = notificationService;
    }
}
```
Правильно:
```java
@Service
@RequiredArgsConstructor
public class SubscriberService {
    private final SubscriberRepository subscriberRepository;
    private final PricePlanRepository pricePlanRepository;
    private final NotificationService notificationService;
}
```

### SPR-104

В Spring Data репозиториях названия параметров в @Param при нативных запросах должны быть только в snake_case. snake_case соответствует соглашениям SQL и улучшает читаемость запросов. Обеспечивает единообразие именования параметров в запросах.

Неправильно:
```java
@Repository
public interface SubscriberRepository extends JpaRepository&lt;SubscriberEntity, Long&gt; {
    @Query(value = "SELECT * FROM subscribers WHERE phone_number = :phoneNumber AND is_active = :isActive",
           nativeQuery = true)
    List&lt;SubscriberEntity&gt; findByPhoneNumberAndActive(@Param("phoneNumber") String phoneNumber,
                                                      @Param("isActive") Boolean isActive);
}
```
Правильно:
```java
@Repository
public interface SubscriberRepository extends JpaRepository&lt;SubscriberEntity, Long&gt; {
    @Query(value = "SELECT * FROM subscribers WHERE phone_number = :phone_number AND is_active = :is_active",
           nativeQuery = true)
    List&lt;SubscriberEntity&gt; findByPhoneNumberAndActive(@Param("phone_number") String phoneNumber,
                                                      @Param("is_active") Boolean isActive);
}
```

### SPR-105

Не рекомендуется работать с jpa-энтити вне сервисов, которые выбирают данные из хранилища (т.е. вне тех, которые обращаются непосредственно к репозиторию). При необходимости передачи данных из jpa-энтити в вышестоящие/горизонтальные слои использовать модели. Изоляция JPA-сущностей в слое доступа к данным улучшает разделение ответственности и предотвращает утечку деталей реализации БД в бизнес-логику.

Неправильно:
```java
@RestController
public class SubscriberController {
    private final SubscriberService subscriberService;
    @GetMapping("/subscribers/{id}")
    public SubscriberEntity getSubscriber(@PathVariable Long id) {
        SubscriberEntity entity = subscriberService.findById(id);
        return entity;
    }
}
```
Правильно:
```java
@RestController
public class SubscriberController {
    private final SubscriberService subscriberService;
    @GetMapping("/subscribers/{id}")
    public Subscriber getSubscriber(@PathVariable Long id) {
        Subscriber subscriber = subscriberService.findById(id);
        return subscriber;
    }
}
```

### SPR-106

С энтити мы работаем только в "доменных" сервисах, а в остальных слоях используем модели. Нецелесообразно только в одном месте использовать User для энтити, а в куче других мест постоянно писать UserModel. Поэтому настоятельно рекомендуется энтити именовать с суффиксом Entity. Правило проверяет классы с аннотацией @Table (JPA и Spring Data JDBC).

Неправильно:
```java
@Entity
@Table(name = "subscribers")
public class Subscriber {
    @Id
    private Long id;
    private String phoneNumber;
}
```
Правильно:
```java
@Entity
@Table(name = "subscribers")
public class SubscriberEntity {
    @Id
    private Long id;
    private String phoneNumber;
}
```

### SPR-109

При работе с нативными запросами и использовании RowMapper-ов рекомендуется обращаться к колонкам результата по названиям колонок, а не по индексам. Обращение по именам колонок улучшает читаемость и делает код более понятным. Предотвращает ошибки при изменении порядка колонок в SELECT-запросе.

Неправильно:
```java
jdbcTemplate.query(sql, (rs, rowNum) -> {
    SubscriberReport report = new SubscriberReport();
    report.setId(rs.getLong(1));
    report.setPhoneNumber(rs.getString(2));
    report.setBalance(rs.getBigDecimal(3));
    report.setCreatedDate(rs.getTimestamp(4).toLocalDateTime());
    return report;
});
```
Правильно:
```java
jdbcTemplate.query(sql, (rs, rowNum) -> {
    SubscriberReport report = new SubscriberReport();
    report.setId(rs.getLong("id"));
    report.setPhoneNumber(rs.getString("phone_number"));
    report.setBalance(rs.getBigDecimal("balance"));
    report.setCreatedDate(rs.getTimestamp("created_date").toLocalDateTime());
    return report;
});
```

### SPR-302

Периодичность/крон-выражение выполнения джоба обязательно должно быть вынесено в application.yml. Для этого в аннотации @Scheduled необходимо использовать параметры, принимающие строку: cron, fixedRateString, fixedDelayString. Параметры fixedRate и fixedDelay принимают числовые значения и не поддерживают SpEL-выражения, что не позволяет вынести расписание в конфигурацию.

Неправильно:
```java
@Scheduled(fixedRate = 60000)
public void updateBalances() {
    // ...
}
@Scheduled(fixedDelay = 30000)
public void syncData() {
    // ...
}
```
Правильно:
```java
@Scheduled(cron = "${app.call-history.archiver.cron}")
public void archiveOldCallHistory() {
    // ...
}
@Scheduled(fixedRateString = "${app.subscriber.balance-updater.rate}")
public void updateBalances() {
    // ...
}
@Scheduled(fixedDelayString = "${app.subscriber.sync.delay}")
public void syncData() {
    // ...
}
```

### SPR-902

Не следует использовать конкатенацию строк для формирования сообщений в логах при использовании SLF4J, Log4j. Использование параметризованных сообщений улучшает производительность за счёт отложенного формирования строки. Упрощает читаемость кода и уменьшает вероятность ошибок при форматировании сообщений.

Неправильно:
```java
logger.info("User " + userId + " has logged in from IP " + ipAddress);
```
Правильно:
```java
logger.info("User {} has logged in from IP {}", userId, ipAddress);
```
