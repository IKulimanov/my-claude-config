#!/usr/bin/env bash
# Общая библиотека аналитики по ~/.claude/logs/*.jsonl.
# Используется analyze-usage.sh и collect-weekly.sh: правила подсчёта
# (регексы, фильтрация по времени/проекту) живут в одном месте, чтобы
# отчёт и недельные снапшоты никогда не расходились в методике.

# Каталог логов хуков (переопределяется CLAUDE_LOG_DIR — так работают тесты).
usage_log_dir() {
  echo "${CLAUDE_LOG_DIR:-$HOME/.claude/logs}"
}

# Тест-файлы для TDD-сигнала (Java/Go/JS-TS + каталоги tests).
USAGE_TEST_RE='(Test|Tests)\.java$|_test\.go$|\.(test|spec)\.(ts|js|tsx|jsx)$|/(test|tests|__tests__)/'
# Команды запуска тестов.
USAGE_RUN_RE='mvn .*test|gradle.*test|gradlew.*test|go test|npm( run)? test|yarn test|pnpm test|vitest|jest|pytest'
# Валидная slash-команда: /token целиком. Защищает от старых повреждённых
# записей (многострочный промпт в slash_command) и от путей вида /Users/... .
USAGE_SLASH_RE='^/[A-Za-z][A-Za-z0-9_:-]*$'

# usage_filter_range <file> <since> <until> [project]
# Построчный фильтр строгого JSONL по интервалу [since, until) и проекту.
# Логи — одна запись на строку (гарантирует hook_log); читаем через -R +
# fromjson?, чтобы единичная битая строка пропускалась, а не роняла отчёт.
# Пустой <until> = без верхней границы. Отсутствующий файл — не ошибка.
usage_filter_range() {
  local file="$1" since_ts="$2" until_ts="${3:-}" project="${4:-}"
  [ ! -f "$file" ] && return 0
  [ -z "$until_ts" ] && until_ts="9999-12-31T23:59:59Z"
  if [ -n "$project" ]; then
    jq -cR --arg since "$since_ts" --arg until "$until_ts" --arg proj "$project" \
      'fromjson? | select(.ts >= $since and .ts < $until and .project == $proj)' "$file"
  else
    jq -cR --arg since "$since_ts" --arg until "$until_ts" \
      'fromjson? | select(.ts >= $since and .ts < $until)' "$file"
  fi
}
