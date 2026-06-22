---
name: go-service
description: Lean entry point for Go side/home projects. Thin wrapper that defers to go-best-practices for all detailed guidance. For production code or review, use go-best-practices directly (it auto-triggers on **/*.go).
---

# Go Service (lean profile)

Тонкий профиль для небольших домашних Go-сервисов. Детальная часть (структура, ошибки,
concurrency, тесты) живёт в `go-best-practices` — он же авто-триггерится на `**/*.go`.
Этот скил оставлен как именованная точка входа; дублировать гайдлайны здесь не нужно.

## Workflow

1. Прочитай локальный `CLAUDE.md`.
2. Загрузи `go-best-practices` — основной источник правил по Go.
3. Держи изменения маленькими и идиоматичными; предпочитай стандартную библиотеку.
