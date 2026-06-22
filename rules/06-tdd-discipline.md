# TDD Discipline (iron law)

For any production code change — feature, fix, refactor, design implementation — **no production code is written without a failing test first**.

Order is fixed: **RED → GREEN → REFACTOR**.
1. **RED:** Write a test that exercises the new behavior or reproduces the bug. RUN it. Confirm it fails for the right reason (not "compilation error").
2. **GREEN:** Write the minimal production code to make it pass. RUN the test. Confirm it passes.
3. **REFACTOR:** Improve the code (and the test) without changing behavior. Run tests again.

Rationalizations that DO NOT excuse skipping a test:
- «I'll add the test after» — no.
- «Already manually tested» — no, manual testing is not a regression net.
- «It's a tiny change» — tiny changes are where regressions hide.
- «The test would be trivial» — write the trivial test in 30 seconds.

Exceptions (only these):
- Pure documentation changes (no code).
- Config-only changes that have no behavior (e.g., changing log level — but log assertions count as behavior).
- Exploratory spikes that will be deleted before commit.

If you cannot write a failing test first — STOP and discuss with the user before proceeding.

## Test authorship (кто пишет тест)
Iron-law в силе: падающий тест существует до прод-кода. Но автора теста выбирает пользователь.
- По умолчанию тест пишет Claude. НЕ спрашивать на каждое мелкое изменение (иначе правило бесит).
- Пользователь берёт это на себя фразой «я пишу тесты» (на всю задачу): тогда Claude ждёт тест,
  запускает, подтверждает корректное падение, затем пишет прод-код.
- Вернуть Claude — «пиши тесты сам». Выбор запоминается до конца задачи.
- Для крупной/рискованной задачи можно один раз уточнить авторство в начале; иначе — по умолчанию.
