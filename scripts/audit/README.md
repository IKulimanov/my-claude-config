# scripts/audit — месячный аудит использования Claude Code

Три шага, только стандартная библиотека Python 3.11+. Окно по умолчанию — последние 9 ISO-недель,
выход — `docs/audit-<ГГГГ-ММ>/data/` (в `.gitignore`: там тексты промтов).

```bash
python3 scripts/audit/extract.py            # логи → data/*.json (или --start/--end/--weeks, --out)
python3 scripts/audit/report_phase1.py      # → data/metrics.json + data/tables.md (читать его)
```

Что смотреть раз в месяц (20 минут): 5 индикаторов из `docs/audit-2026-08/05-growth.md`, раздел 7 —
блоки «Rule 08 baseline», «Коррекции по неделям», «Мёртвые команды/агенты», «Делегирование с риском»,
«Объём по неделям» в `tables.md`. Список установленных команд/агентов/skills скрипт берёт из репозитория.

- `audit_lib.py` — окно, таймзона, классификаторы (тип задачи, вид реплики, риск-делегирование, гипотеза).
- `extract.py` — `~/.claude/history.jsonl` + `~/.claude/logs/*.jsonl` + `~/.claude/projects/**/*.jsonl` → JSON.
- `report_phase1.py` — метрики и таблицы.
- `build_report.py` — собирает `docs/audit-2026-08/report.html` из `01–07*.md` + `metrics.json` (разовый отчёт
  августа 2026; для месячного прогона не нужен).

Отличие от `scripts/analyze-usage.sh`: там быстрые счётчики за N дней; здесь классификация промтов и разбор
транскриптов (итерации, паузы, загрузки skills, гипотезы).
