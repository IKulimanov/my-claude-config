# Extension Guide

## Decision Rule: Where Should New Guidance Live?

Add a new item to `rules/` only if all of these are true:
- it applies to almost every project
- it changes rarely
- it is short enough to justify always-on tokens
- violating it creates real cost or risk

Add a new item to `commands/` when:
- the workflow has a stable sequence
- you want consistent outputs
- the task is repeated often

Add a new item to `agents/` when:
- the task needs judgment or tradeoff analysis
- a fixed checklist is not enough
- you want a clear role boundary

Add a new item to `skills/` when:
- the knowledge is domain-specific
- you do not want it always loaded
- it can be reused across projects or sessions

Add a new hook when:
- the mistake is costly and recurrent
- the detection rule is simple and reliable
- false positives will stay low

## Script vs Prompt: When to Make a Callable Helper

Inspired by configs that call helper scripts (clipboard grab, renderers) instead of re-deriving the
same procedure in prose each run.

Decision rule:
- **deterministic + repeatable + no judgment → script.** Put it in `scripts/helpers/`, call it from
  the command. A script is fast, costs no tokens, is testable, and produces identical output every
  run. Example: scaffolding the `.ai/` skeleton (`ai-init.sh`).
- **needs context or judgment → prompt.** Keep it in the command/agent body. Examples: planning,
  review reasoning, changelog selection, distilling a correction into a rule.

Anti-pattern: an LLM re-computing a mechanical recipe (parsing, geometry, fixed file layout) on every
invocation. If the steps are the same regardless of input meaning, it is a script.

Conventions for `scripts/helpers/`:
- `set -euo pipefail`, clear `Usage:` on bad args, non-zero exit on failure (never pretend success).
- These are command helpers, not installers — they act immediately when called (no `--apply` gate),
  but stay idempotent and low-risk (touch only the local work repo, e.g. `.ai/` and its `.gitignore`).
- A `-n` / `--dry-run` flag is welcome for anything that writes files.
- Add a test under `tests/` first (iron-law TDD): a self-contained `test-<name>.sh` that prints
  `OK: ...` on success and `FAIL: ...` to stderr with a non-zero exit otherwise.

## Good First Extensions

- a stack overlay skill for your primary runtime
- a code-generation command for your most common feature flow
- a project onboarding command for large repositories
- a prompt review skill for agent/system prompt changes
- a release-review command if you ship frequently

## Anti-Patterns

- putting every preference into global rules
- creating many overlapping skills
- making commands that are just long prompt dumps
- hiding project-specific constraints in global files
- adding hooks for stylistic nits instead of real risk

## Review Checklist Before Adding Anything

- What failure mode does this solve?
- Does it belong globally or locally?
- Is the guidance stable enough to stay maintainable?
- Could this be a skill instead of a rule?
- Could this be a command instead of another long prompt?
- How will I know it improved outcomes?

## Suggested Growth Order

1. Project `CLAUDE.md`
2. Skills
3. Commands
4. Agents
5. Rules
6. Hooks

This order keeps token cost and maintenance burden under control.

## Как добавить новый компонент (перенесено из README)

### Skill
Структура: `skills/<name>/SKILL.md` (+ `references/` для объёмных материалов).
Процесс: убедись, что это skill (не rule/command) → узкое имя → короткое `description`
для триггеринга → в SKILL.md только workflow и guardrails, детали в `references/` →
проверь дубли с существующими skills. Не делай skill слишком широким, не копируй
полдокументации, не тащи project-specific договорённости в общий skill.

### Command
Нужна, когда хочешь зафиксировать повторяемый workflow: файл в `commands/`, короткий
`description`, когда применять, шаги, ожидаемый формат результата. Команда ведёт агента
по процессу, а не является длинным куском текста.

### Agent
Только если реально нужна новая роль. Ответь заранее: зона ответственности; чем
отличается от существующих; какие tools действительно нужны; где остановиться и
спросить; как выглядит успешный результат. Если неясно — нужен command или skill.

### Rule
Правило подходит для `rules/`, только если: относится почти ко всем проектам, короткое,
устойчиво во времени, не место ему в project CLAUDE.md и оно не оформляется как skill.

### Порядок роста без хаоса
1. CLAUDE.md конкретных проектов → 2. повторяемые знания в `skills/` → 3. устойчивые
процессы в `commands/` → 4. узкие `agents/` → 5. в последнюю очередь `rules/`.
Это защищает always-on слой от разрастания.
