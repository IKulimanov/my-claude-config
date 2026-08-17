# 08 — Финальное ревью репозитория (2026-08-16)

Проверено: переусложнение, мусор/устаревшее, понятность для работы и месячного анализа, работа через Claude Desktop,
шпаргалка по командам. Стек — markdown + bash + python, ревью напрямую. Тесты: 14 → 12 после чистки, все зелёные.

## Находки (по серьёзности)

### WARNING — два пайплайна аналитики (переусложнение)
Недельный (`scripts/collect-weekly.sh` 350 строк, `run-weekly-review.sh` 174, `install-weekly-analytics.sh` 152,
`render-dashboard.sh` 83, `scripts/lib/usage-lib.sh`, `templates/dashboard.html.template`, `analytics/` со снапшотами
W21–W28, `analytics/weekly-review-prompt.md`, 5 тестов) **остановился 11 июля** (последний снапшот W28), launchd так и не
применён. Месячный (`scripts/audit/`, 3 скрипта) делает всё то же плюс классификацию промтов, итерации, skills,
гипотезы. Два инструмента на одну задачу — ровно тот оверинжиниринг, который аудит и нашёл.
**Рекомендация:** оставить `analyze-usage.sh` (быстро, 7 дней) + `scripts/audit/` (месяц); недельный удалить.
Файлы не в git — удаление необратимо, поэтому команда за тобой:

```bash
rm -rf analytics scripts/collect-weekly.sh scripts/run-weekly-review.sh scripts/install-weekly-analytics.sh scripts/render-dashboard.sh templates/dashboard.html.template tests/test-collect-weekly.sh tests/test-weekly-schema.sh tests/test-render-dashboard.sh tests/test-run-weekly-stub.sh
```

После удаления: убрать строку `analytics/` из таблицы в `README.md`, `usage-lib.sh` оставить (его использует
`analyze-usage.sh`), тест `tests/test-analyze-usage.sh` остаётся. Если оставляешь пайплайн — тогда применить launchd
и убрать «остановлен» из README; половинчатое состояние хуже любого из двух.

### WARNING — устаревшее и мусор (сделано / за тобой)
Сделано (всё в git, обратимо `git checkout HEAD -- <path>`):
- `docs/RESEARCH_FINDINGS.md` (295 строк, каталог идей из чужих репо, май) — удалён; это бэклог тюнинга, а конфиг теперь
  меняется по данным аудита. Ссылки в `ROADMAP.md`/`EXTENSION_GUIDE.md` поправлены.
- `scripts/repair-logs.sh` — разовый фиксер старых логов (корневая причина устранена в hook_log) — удалён.
- `scripts/helpers/render-doc.sh`, `collect-diff.sh` + их тесты — ни одна команда их не вызывает (шапки скриптов
  утверждали обратное) — удалены. `ai-init.sh` используется (`/task`, `/review`, `/review-mr`) — оставлен.
- `.DS_Store` в дереве — удалены (и так в `.gitignore`).
За тобой (не в git, необратимо):
- `docs/AI_USAGE_AUDIT_2026-07.md` — заменён августовским аудитом; удалить.
- `digest-routine.md` (357 строк, не подключён с июня) — удалить.
- `docs/ROADMAP.md` (407 строк, эмодзи-чеклист «High ROI / Средний / Стратегические») — у тебя незакоммиченные правки,
  поэтому не трогал содержимое. Предлагаю сократить до «что сделано» + 3 открытых пункта из `CLAUDE.md`; всё
  «стратегическое» — это список поводов настраивать инструменты.
- `docs/DEVELOPER_TIPS.md` (197) дублирует `USAGE_GUIDE.md`/`WORKFLOW.md` — слить в `WORKFLOW.md`, когда будешь
  коммитить свои правки доков.

### SUGGESTION — понятность (сделано)
- `README.md`: аналитика = 2 команды (быстрый отчёт + месячный аудит), ссылка на протокол и `docs/audit-2026-08/`,
  таблица доков без недельного пайплайна, требования (`jq`, `python3`).
- `CLAUDE.md`: секция «Текущий фокус» переписана: принцип «менять только по данным, ≤7 изменений, удалять больше,
  чем добавлять», что сделано, что открыто, что осознанно НЕ в работе (Jira MCP, skill-creator, plugin).
- `docs/WORKFLOW.md`: в начале шпаргалка «команда → что делаю сам → что отдаю» и прямой ответ про тесты.
- `scripts/audit/`: окно и каталог параметризованы (`--start/--end/--weeks`, по умолчанию последние 9 недель →
  `docs/audit-<ГГГГ-ММ>/data/`), список команд/агентов/skills берётся из репо, `.gitignore` — `docs/audit-*/data/`.
  Месячный прогон = 2 команды без правки кода. `scripts/audit/README.md` переписан.
- `rules/06`: разделение авторства тестов по умолчанию — случаи (что) подтверждаешь/дополняешь ты, код (как) пишет
  Claude; секция «Тесты» в `plan-template.md` — список случаев.

## Будет ли работать через Claude Desktop — да, с одной оговоркой

По логам (48 Desktop-сессий, `entrypoint: claude-desktop`, в основном lifeOS/Lark/teacher-pro):
- `~/.claude/CLAUDE.md` и rules — грузятся (`instructions.jsonl`: 3137 загрузок в lifeOS-сессиях, включая все `rules/*.md`).
- Slash-команды — работают: `/review` 5, `/feature` 4, `/task`, `/plan`, `/arch` вызваны из Desktop.
- Субагенты — работают: `java-reviewer` 6, `go-test-writer` 5, `vue-reviewer` 2, `general-purpose` 41, `Explore` 26.
- Skills через инструмент `Skill` — работают (`jira`, `vue-frontend`, `go-best-practices`).
- Хуки — работают: `tools.jsonl` 2279 строк из lifeOS-сессий, `blocks.jsonl` 5 блокировок; значит `settings.json`
  читается и в Desktop.
- **Не проверяемо по логам:** `outputStyle: personal` (стиль вывода) — в транскриптах системный промт не виден. Скорее
  всего работает (тот же `settings.json`), проверка простая: в Desktop спросить что-нибудь и посмотреть, отвечает ли
  по-русски коротко. Rule 07 (язык) в любом случае действует через CLAUDE.md.
- Rule 08 (AskUserQuestion) — инструмент есть в Desktop (241 вызов за окно, часть из Desktop-сессий).

## Шпаргалка по командам

Перенесена в `docs/WORKFLOW.md` (начало файла), чтобы быть под рукой, а не в отчёте. Суть в одну строку:
**думать — сам, набирать — агент**; гипотеза, вариант решения, случаи для тестов и первый проход по MR — твои;
код тестов, boilerplate, форматирование, git, Sonar-правки, оформление — агенту.

## Итог по репозиторию после чистки

commands 14 (13 + `/adr`), agents 7, skills 17, rules 8, hooks 11 скриптов, tests 12 (зелёные), docs 9 + `audit-2026-08/`.
Что мешает назвать репозиторий «понятным» прямо сейчас — только висящее решение по недельному пайплайну и три
неотслеживаемых файла выше. Это 1 команда `rm` и 5 минут.
