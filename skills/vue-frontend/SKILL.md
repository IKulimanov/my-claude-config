---
name: vue-frontend
description: Use for Vue 3 + Vite frontend projects. Covers Composition API, script setup, Pinia, Vue Router, component design, Vitest, TypeScript integration, and Vite configuration.
paths: "**/*.vue,**/vite.config.*"
---

# Vue Frontend

Use this skill when working in a Vue 3 + Vite frontend project.

## When To Use

- Vue component development (new or modifying existing)
- Pinia store creation or modification
- Vue Router configuration
- Vitest test writing or review
- Vite configuration and build optimization
- TypeScript integration in Vue projects

## Workflow

1. Read the local project `CLAUDE.md`.
2. Detect project setup: check `package.json` for Vue version, Vite, Pinia, Vue Router, TypeScript.
3. Load the relevant reference:
   - `references/composition-api.md` for component patterns
   - `references/state-routing.md` for Pinia and Vue Router
   - `references/testing-vue.md` for Vitest + Vue Test Utils
4. Match existing project conventions (file naming, directory structure, CSS approach).
5. If the project uses TypeScript, enforce proper typing throughout.

## Guardrails

- Use Composition API with `<script setup>` - never Options API in new code.
- Props must have type declarations and default values where appropriate.
- Emits must be declared with type validation.
- Never mutate props directly - emit events to parent.
- Keep components focused: one responsibility per component.
- Prefer computed properties over methods for derived state.
- Use `defineModel()` for two-way binding (Vue 3.4+).
- Reactive state: `ref()` for primitives, `reactive()` for objects.
- Don't use `reactive()` for values that get reassigned - use `ref()`.
- Keep template logic minimal - extract to composables or computed properties.
- Always unsubscribe/cleanup in `onUnmounted` for manual listeners and intervals.
