# Интерпретация флоу (на примере PG-1)

> Внимание: документ написан до переноса флоу и шаблонов в БД (таблицы `FLOWS` и
> `SCRIPT_TEMPLATES`, версия = запись), согласующих (параметр стадии +
> `DATABASE_APPROVERS`) и флагов ручного режима (`FLOWS.manual_mode`,
> `DICT_DATABASES.manual_mode`); статусы и результаты выполнения живут в `EXECUTION_STEPS`
> (в тексте ниже — `STEP`) — детали хранения и API исполнителя смотреть в
> 01-design. Принципы в силе: асинхронные стадии, единственная точка продвижения
> `completeStage`, один вход внешних событий, контракты хендлеров.

Как yml-флоу превращается в работающую задачу: кто его читает, какие обработчики
нужны, в какой момент и куда записываются скрипты для исполнителя.

## Кто что знает

| Компонент | Знает | Не знает |
|---|---|---|
| Движок (бэкенд дашборда) | флоу целиком: стадии, слушатели, словари; единственный интерпретатор | креды целевых БД |
| Исполнитель | только задача + шаги: забрал по REST, выполнил по порядку, отчитался по каждому шагу | флоу, стадии, слушатели, Jira |
| Адаптер источника (Jira/Zabbix) | вебхук -> переменные флоу (блок `variables`, атрибут `from`); outbox-доставки -> переходы/комментарии | бизнес-логика флоу |

Флоу — программа для движка. Исполнитель и Jira видят только артефакты
интерпретации: строки `STEP` и записи outbox.

## Приём вебхуков — не стадия

Вебхуки приходят разные (создание, решение согласования, изменение заявки), и на
каждый движок выполняет маппинг и валидацию по блоку `variables`:

1. адаптер переводит поля вебхука в переменные флоу (`variables`, атрибут `from`);
2. задачи по `external_ref` нет и это вебхук создания: флоу не найден — событие
   пропускается (задача не создаётся, статус заявки не меняется, DBA
   уведомляются); флоу найден — валидация required и словарей; успех — создаётся
   `TASKS` и стартует первая стадия; провал — `TASKS` «Не распознана», а реакцию в
   источнике («Отменена» с комментарием для Jira, уведомление для Zabbix)
   выполняет адаптер — это механика, не конфиг флоу;
3. задача есть, значения не изменились: обрабатывается само событие вебхука
   (решение согласования и т.п.);
4. задача есть, значения изменились:
   - до подтверждения (confirm): перевалидация, обновление `input_values` и
     возврат задачи на начало флоу — согласование проходит заново, `prepare`
     пересобирает автошаги (кастомные шаги DBA сохраняются);
   - после подтверждения: изменения не применяются, в заявку уходит комментарий;
   - изменённые данные невалидны: не применяются, комментарий в заявку, задача
     не двигается.

## Принцип: стадии асинхронные

`start` стадии — действие движка; завершение приносит внешний сигнал:

| Стадия | Хендлер | Что делает start | Кто и чем завершает |
|---|---|---|---|
| approval | `jira-approval` | собирает согласующих (параметр стадии + каталог по БД) | вебхук решения из Jira (согласовать должны все) |
| prepare | `task-preparation` | собирает `STEP` из словаря шагов: условия, биндинги, `final_script` | движок, синхронно |
| confirm | `dashboard-approval` | назначает задачу DBA по `db-assignments` | клик DBA на дашборде |
| execute | `database-execution` | переводит задачу в «Готова к выполнению» — исполнитель заберёт её по REST | REST-отчёты исполнителя: все шаги done / шаг упал |
| deliver | `email-delivery` | кладёт письмо в outbox | доставка outbox |

У стадии может быть `expression` — JEXL над `input_values`; поля каталожной записи
словарной переменной доступны через точку (`database_code.critical`). Ложь на входе
в стадию — стадия пропускается (skipped), её события не эмитятся. Так confirm
включается только для прода и критичных БД, а approval в ORA-2 — только для опасных
областей прав.

Единственная точка продвижения — `completeStage(task, stage, outcome)`: движок в одной
транзакции фиксирует исход, пишет outbox-записи слушателей и открывает следующую
стадию. Best-effort слушатели (`notify`) уходят после коммита.

## Скрипты: три момента записи

1. **Сборка — стадия `prepare`** (после согласования: задачу, которую могут
   отклонить, не собираем). Источник шагов — параметр `steps` самой стадии.
   Хендлер вычисляет `expression` каждого шага по
   `input_values` (например `grant_now and scope == 'schema'` — шаг выдачи прав
   включён или нет), резолвит биндинги `input`/`db_catalog` прямо в текст шаблона и
   пишет строки `STEP`: position, code, ссылка+версия шаблона, kind (check/action),
   `final_script`, статус waiting. Биндинги `generator`/`step_output` остаются в
   `final_script` плейсхолдерами — их значения существуют только в runtime
   исполнителя. Не собралось (не разрешился биндинг, нет шаблона) — задача
   «Ошибка», разбор DBA с дашборда. Изменение данных заявки до подтверждения
   возвращает задачу на начало флоу: согласование заново, автошаги пересобираются
   (кастомные — сохраняются).
2. **Правки DBA до подтверждения (confirm)** — отключить/добавить/переставить шаг,
   поправить текст. Только в `STEP` этой задачи; словарь и флоу не меняются.
   Подтверждение фиксирует снапшот — дальше шаги не меняются ни правками, ни
   вебхуками.
3. **Дособирание исполнителем** — перед запуском каждого шага: `generator.password` ->
   сгенерировать (нигде не сохранять), `step_output` -> из `STEP.result` предыдущих
   шагов (колонки итогового SELECT по `output_keys` шаблона).

## Карта событий и слушателей PG-1

| Точка | Событие | Обработчики |
|---|---|---|
| приём (адаптер) | флоу не найден / поля не распознаны | «Отменена» с комментарием — механика адаптера, во флоу не описывается |
| approval | on-start | `jira-transition` «На согласовании» + поле согласующих; `notify` task-created |
| approval | on-success | `notify` task-approved |
| approval | on-reject | `jira-transition` «Отменена» + `task-rejected` |
| prepare | on-error | — (задача «Ошибка», разбор DBA с дашборда) |
| confirm | on-reject | `jira-transition` «Отменена» + `task-rejected` |
| execute | on-start / on-success / on-error | `notify` телеграм-пинги |
| deliver | on-success | `jira-transition` «Готово» + `task-done` |

Гарантия доставки — свойство обработчика: `notify` — best-effort;
`jira-transition`, `email-delivery` — outbox с ретраями. Событие `on-start`
эмитится после инициализации стадии хендлером — поэтому `${{ stage.approvers }}`
в слушателе уже вычислен.

## Java-скелет

Определение флоу — типизированные record'ы, имя хендлера — дискриминатор:

```java
public record FlowDefinition(String name, String code, Source source, String externalKey,
                             Map<String, VariableDef> variables, List<StageDef> stages) {}

public record StageDef(String code, String name, String handler,
                       @JsonTypeInfo(use = Id.NAME, include = As.EXTERNAL_PROPERTY, property = "handler")
                       StageParameters parameters,
                       Map<StageEvent, List<ListenerCall>> listeners) {}

public sealed interface StageParameters
        permits TaskPreparationParams, JiraApprovalParams, DashboardApprovalParams,
                DatabaseExecutionParams, EmailDeliveryParams {}

public record TaskPreparationParams(DictionaryRef steps, CustomSteps customSteps) implements StageParameters {}
public record JiraApprovalParams(DictionaryRef approvers, Quorum quorum) implements StageParameters {}
public record DatabaseExecutionParams(String database) implements StageParameters {}
```

Лишний или неизвестный ключ в yml — ошибка Jackson при старте; ссылки на словари и
шаблоны, парс JEXL-выражений проверяет отдельный валидатор (fail fast).

Контракты обработчиков:

```java
// стадия: start только начинает, завершение приносит внешний сигнал через onEvent
public interface StageHandler<P extends StageParameters> {
    String code();                               // "jira-approval"
    Set<StageEvent> events();                    // START, SUCCESS, REJECT
    void start(TaskContext task, P params);
    // сигнал для активной стадии: решить, завершена ли она.
    // empty — стадия продолжает ждать (например, кворум ещё не собран)
    Optional<StageOutcome> onEvent(TaskContext task, P params, ExternalEvent event);
}

// слушатель: сам объявляет свою гарантию доставки
public interface ListenerHandler<P> {
    String code();                               // "jira-transition"
    DeliveryGuarantee guarantee();               // BEST_EFFORT | OUTBOX
    void handle(TaskContext task, P params);
}
```

Движок:

```java
@Transactional
public void completeStage(long taskId, String stageCode, StageOutcome outcome) {
    var task = taskDao.lock(taskId);
    var stage = flowRegistry.flowOf(task).stage(stageCode);
    taskDao.saveOutcome(task, stage, outcome);
    for (var call : stage.listeners(outcome.event())) {
        if (handlerOf(call).guarantee() == OUTBOX) outboxDao.enqueue(task, call);
    }
    advance(task);                               // следующая стадия или терминал
    afterCommit(() -> fireBestEffort(task, stage, outcome));
}
```

Все внешние сигналы — вебхук Jira (approval), клик DBA на дашборде (confirm),
REST-отчёт исполнителя (execute), доставка outbox (deliver) — заходят в один вход:

```java
public void onExternalEvent(Task task, ExternalEvent event) {
    var stage = flowOf(task).stage(task.currentStage());
    handlerOf(stage).onEvent(task, stage.parameters(), event)
        .ifPresent(outcome -> completeStage(task.id(), stage.code(), outcome));
}
```

Хендлер решает, завершена ли его стадия; движок решает, куда дальше.

Исполнитель — отдельный сервис; связь только «исполнитель -> дашборд» по REST,
о флоу не знает:

```java
var task = api.claimReadyTask();                 // POST /executor/tasks/claim — атомарный захват
if (task == null) return;                        // пусто — следующий опрос
var results = new HashMap<String, Map<String, String>>();
for (StepDto step : task.steps()) {              // по position, кроме disabled
    String script = placeholders.resolve(step.finalScript(), results); // generator/step_output
    StepResult r = sqlRunner.run(task.database(), script);  // креды — ADR-001, только у исполнителя
    results.put(step.code(), r.outputs());
    api.reportStep(task.id(), step.code(), r);   // POST result; идемпотентно, с ретраями
    if (r.failed()) return;                      // остальные шаги дашборд пометит skipped
}
```

Контроллер отчётов на дашборде сохраняет `STEP` + журнал и передаёт событие в
`onExternalEvent`; хендлер execute считает шаги: результат последнего и все ок —
SUCCESS, упавший шаг — ERROR, промежуточный — empty (ждём следующего отчёта).

## Открытые вопросы

1. Пароль для deliver: `${{ generator.password }}` существует только в runtime
   исполнителя и не сохраняется — движку взять его неоткуда. Решение — ADR-004
   (кандидат: короткоживущее хранилище, пароль зашифрован ключом дашборда;
   протух TTL — ретрай deliver требует шага reset-password).
2. Решено (зафиксировано в 01-design, «Сценарии отказа»): идемпотентность
   `jira-transition` — требование адаптера: переход в текущий статус считается
   no-op, иначе outbox-ретраи зациклятся.
3. Отменено: события clarify нет — возврата на уточнение не существует; DBA либо
   подтверждает, либо отклоняет.
4. Пересборка шагов при изменении данных: политика «автошаги пересобираются,
   кастомные шаги DBA сохраняются» — но кастомный шаг мог ссылаться на старые
   значения; DBA уведомляется и перепроверяет при подтверждении. Подтвердить.
