# Git и защищённые пути

- Агент не пушит, не мержит, не делает rebase и pull, не переключается на master/main/staging/prod
  и не коммитит в них. Работа - в локальной ветке от master; push, merge и MR делает пользователь.
- Ветка: `{type}/{JIRA-ID}-{описание}`; в рабочем проекте без Jira-ID ветку не предлагать, в личном
  (профиль personal, правило 10) Jira-ID не требуется и не спрашивается.
  Коммит: рабочий проект (профиль work) - `ORSP-1234: Добавить ...` (ID из имени ветки); личный -
  `feat(scope): добавить ...`. Русский, инфинитив, первая строка <= 72 символа, без трейлеров.
  Хуки `check-commit-msg`, `guard-git` проверяют это; примеры - скил `git-convention`.
- `.gitlab-ci.yml`, `.gitlab/`, `helm/` - только по явной просьбе (хук `guard-paths` спросит);
  проектный `.claude/settings.local.json` расширяет список.
- reset --hard, clean -f, branch -D, stash drop, checkout/restore файлов, commit --amend - после
  подтверждения; rm -rf - только сборочные и scratch-каталоги.
- Миграции Liquibase/Flyway на staging/prod из чата не выполняются. Vault-секреты не пишутся в код,
  конфиг, лог, Dockerfile; хардкод секрета - CRITICAL в ревью.
