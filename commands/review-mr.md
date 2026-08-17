---
description: Review a colleague's merge request against master — Russian output, convention-first with convention codes, saved to disk. Use for peer MR/PR review of Java/Spring branches.
argument-hint: <MR id or URL, or branch name; empty = current branch>
allowed-tools: Read, Grep, Glob, Bash, Agent, Write
---

# Review MR (ревью MR коллеги)

Ревью изменений коллеги относительно `master`. Приоритет №1 — java-convention.
Результат на русском, в фиксированном формате, сохраняется на диск.

## Шаг 1 — Получить дифф и метаданные

Аргумент `$ARGUMENTS` — id/URL MR, имя ветки или пусто. Предпочтительно `glab` (без checkout).

1. Если задан MR id/URL и доступен `glab`:
   - Метаданные: `glab mr view <id> -F json` → `author.username`, `title`, `source_branch`, `target_branch`, `web_url`.
   - Дифф: `glab mr diff <id>`.
2. Иначе (ветка или текущая):
   - `git fetch origin`
   - База: `master` (если её нет — `main`). `BASE=origin/<base>`.
   - Ветка: аргумент или текущая (`git rev-parse --abbrev-ref HEAD`).
   - Дифф: `git diff $BASE...<branch>` (three-dot — только изменения ветки от точки расхождения).
   - Автор: самый частый в `git log $BASE..<branch> --format='%an'`.
   - `web_url`/`title` нет — как title взять имя ветки.
3. Зафиксировать метаданные:
   - `project` = `basename "$(git rev-parse --show-toplevel)"`
   - `branch`, `author`, `base`, дата = `date +%F`, short-sha базы = `git rev-parse --short $BASE`.

## Шаг 2 — Загрузить конвенцию (приоритет №1)

- Рабочий проект (cwd под `/Users/ivankulimanov/dev/work/`): коды правил брать из Sonar-выжимки
  `~/dev/my-claude-config/skills/java-service-convention/references/sonar-rules.md` (совпадает с CI
  Sonar по кодам LANG-/SPR-/DB-). За «почему» и детали — каноническая конвенция
  `/Users/ivankulimanov/dev/work/java/convention-java/docs/` (`index.md` + релевантные диффу разделы).
  Если выжимки нет — коды из заголовков канона (`### LANG-410`, `### SPR-902`).
  `sonar-rules.md` — внутренний материал: цитируй коды, не вставляй его текст дословно.
- Прочий проект: guardrails из скила `java-service-convention`.

## Шаг 3 — Проанализировать

Делегировать агенту `java-reviewer` (read-only): передать дифф + обязательный формат из Шага 4.
Агент ВОЗВРАЩАЕТ текст ревью на русском; файл пишет эта команда (у агента нет инструмента Write).

Приоритеты: (1) нарушения конвенции с кодами; (2) баги и регрессии; (3) безопасность; (4) тесты.

## Шаг 4 — Формат каждой находки (русский)

Сначала нарушения конвенции (с кодами), затем остальное.

```markdown
### [<КОД>] <короткое понятное сообщение: в чём проблема>
**Где:** <file>:<line>
**Что и почему:** где и в чём проблема, почему важно; что про это есть в конвенции/документации.
**Как починить:** короткий понятный путь (без полной реализации).
**Серьёзность:** CRITICAL | WARNING | SUGGESTION
```

Если код конвенции неприменим — писать `[BUG]`, `[SEC]` или `[—]`. `[—]` — редкость: если находка про стиль,
структуру, логи, исключения, JPA или тесты — код почти всегда есть в `sonar-rules.md`/каноне, найди его.

Шум для автора вреднее пропуска: SUGGESTION — не больше пяти в развёрнутом формате; остальные — одной строкой
списком «Мелочи» в конце (файл:строка — суть). CRITICAL — только то, что нельзя мержить (баг, безопасность,
нарушение инварианта); WARNING — конвенция и риски.

После списка находок — блок «Вопросы автору» (1–3 вопроса, не больше): наводящие вопросы по местам, где
решение спорное, но не ошибочное («почему повтор здесь, а не в клиенте?», «что будет при дубле сообщения?»).
Это для роста автора: вопрос вместо готового ответа. Не дублировать находки; если вопросов нет — блок опустить.

## Шаг 5 — Сохранить ревью

Записать файл (папку проекта создать при отсутствии). В `<branch>`/`<author>` заменить `/` и
пробелы на `-`:

`/Users/ivankulimanov/docs/work/reviews/<project>/<YYYY-MM-DD>__<branch>__<author>.md`

Шапка файла, затем находки из Шага 4:

```markdown
# Review: <title или branch>

- Проект: <project>
- MR: !<id> — <title> (<web_url>)
- Автор: <author>
- Ветка: <source-branch> → <base>
- Дата: <YYYY-MM-DD>
- База ревью: <base> @ <short-sha>

---
```

Строку `MR:` указывать только если метаданные получены через `glab`; иначе пропустить.

Опционально (конвенция `.ai/`, см. `docs/AI_ARTIFACTS.md`): если работаешь внутри репозитория,
продублируй ревью локально, чтобы оно было под рукой при доработках:

```bash
DIR=$(~/dev/my-claude-config/scripts/helpers/ai-init.sh "<branch>")   # создаст .ai/<branch>/, заигнорит .ai/
```

Скопировать тот же текст в `$DIR/review.md`. Основной файл в `~/docs/work/reviews/...` остаётся
источником истины.

## Шаг 6 — Краткий итог в чат

- Путь к сохранённому файлу.
- Счётчик: N CRITICAL, M WARNING, K SUGGESTION.
- Если находок нет — сказать прямо и упомянуть остаточные риски / пробелы в тестах.
- Раз в месяц полезно свести коды по всем ревью проекта (для ретро с командой, без нового инструмента):
  `grep -h '^### \[' ~/docs/work/reviews/<project>/*.md | sed 's/\].*/]/' | sort | uniq -c | sort -rn`
