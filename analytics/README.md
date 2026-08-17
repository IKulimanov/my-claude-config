# Аналитика использования Claude Code

Еженедельный пайплайн: сбор снапшота из `~/.claude/logs/*.jsonl`, анализ недели через
headless `claude -p`, автономный HTML-дашборд. История хранится в git и не теряется.

## Состав

```
analytics/
├── README.md                  # этот файл
├── weekly-review-prompt.md    # промт недельного анализа ({{WEEK}}, {{PREV_WEEK}}, {{REPO}})
├── history/<неделя>.json      # снапшоты метрик, schema_version 1
├── reports/<неделя>.md        # отчёты анализа (или честный стаб при сбое Claude)
└── dashboard.html             # дашборд: открой в браузере, работает офлайн
```

## Конвенция недели

Окно: **суббота 00:00 UTC → пятница 23:59:59 UTC**. Окна тайлятся без щелей — каждая
строка лога принадлежит ровно одному снапшоту. Id = ISO-неделя пятницы окна (`%G-W%V`).
Якорь — первая суббота с логами: 2026-05-16 (окно `2026-W21`).

Следствия:
- запуск субботним утром анализирует неделю, закончившуюся «вчера»;
- выходные относятся к следующей рабочей неделе;
- границы в UTC: сессия около локальной полуночи может «уехать» в соседний день/окно.

## Запуск вручную

```bash
scripts/collect-weekly.sh                  # снапшот последней завершённой недели
scripts/collect-weekly.sh --week 2026-W28  # конкретная неделя (пересоберёт файл)
scripts/collect-weekly.sh --backfill       # все недели с 2026-W21 (существующие пропускает)
scripts/render-dashboard.sh                # перерендерить дашборд из history/ + reports/
scripts/run-weekly-review.sh               # полный цикл: сбор → анализ → дашборд → коммит
scripts/run-weekly-review.sh --force       # пересобрать текущую неделю заново
```

Расписание ставит `scripts/install-weekly-analytics.sh` (launchd: суббота 9:00,
страховочные срабатывания вс/пн — no-op, если отчёт уже есть).

## Словарь полей снапшота (schema_version 1)

| Поле | Смысл |
|---|---|
| `week`, `range`, `generated_at` | id недели, окно [from, to), момент сборки |
| `sessions.total / by_project` | старты сессий (SessionStart) |
| `daily_sessions`, `active_days`, `peak` | сессии по дням, активные дни, пиковый день |
| `tokens.*` | токены за окно: **дельты** кумулятивных стопов по сессиям (см. ниже) |
| `models` | в скольких сессиях встречалась модель |
| `tools.top` | вызовы инструментов (только phase=pre — без двойного счёта) |
| `tools.failures_*` | ошибки инструментов (phase=fail) |
| `skills.top` | Skill-вызовы (`tool=="Skill"` из tools.jsonl) |
| `slash_commands.top` | валидные slash-команды из prompts.jsonl |
| `subagents.top` | запуски субагентов |
| `prompts.*` | число, средняя/медианная длина, % slash, % кириллицы |
| `plan_mode.exit_plan_mode_count` | выходы из plan mode |
| `tdd.*` | правки тест-файлов vs прод-файлов, запуски тестов |
| `blocks.*` | блокировки хуков безопасности по видам |
| `friction.*` | промты с маркерами коррекции («не так», «не работает», wrong…) |
| `enrichment.ccusage` | опциональная стоимость через ccusage (`--ccusage`) |

**Токены.** Строки `stops.jsonl` кумулятивны в рамках сессии (каждый Stop пересуммирует
весь транскрипт). Наивная сумма строк завышает расход на порядки. Коллектор считает
дельту: (последний стоп сессии в окне) − (последний стоп до окна). Сессия, пересёкшая
границу окна, даёт небольшую погрешность на стыке — принято.

## Траблшутинг

- Логи пайплайна launchd: `~/Library/Logs/automations/claude-weekly-analytics.launchd.log`.
- Статус джоба: `launchctl print gui/$(id -u)/com.claude-config.weekly-analytics`.
- Запустить, не дожидаясь субботы: `launchctl kickstart gui/$(id -u)/com.claude-config.weekly-analytics`.
- Отчёт-стаб («анализ не выполнен») означает: снапшот собран, но headless-запуск Claude
  упал — причина в стабе и в launchd-логе. Перезапуск: `scripts/run-weekly-review.sh --force`.
- Тесты пайплайна: `tests/test-collect-weekly.sh`, `test-weekly-schema.sh`,
  `test-render-dashboard.sh`, `test-run-weekly-stub.sh`.
