---
name: web-app
description: Use for server-rendered or lightweight web apps (Go html/template, htmx, Alpine.js, vanilla JS, Web Components). Covers HTML/CSS, security headers (CSP, CORS, XSS), performance budgets, accessibility. NOT for Vue/React/SPA — use vue-frontend for Vue projects.
---

# Web Application Development (server-rendered / lightweight)

Use this skill for building performant, lightweight, and secure web applications that do NOT use a heavy SPA framework. For Vue 3 + Vite projects, use `vue-frontend` instead.

## When To Use

- Server-rendered HTML (Go `html/template`, Jinja, etc.) + handlers
- Sprinkles of interactivity via htmx, Alpine.js, vanilla JS, Web Components
- Reviewing security headers, CSP, CORS, XSS prevention for any web stack
- Performance budget and Core Web Vitals work
- Accessibility (semantic HTML, ARIA, keyboard nav) for any web stack

## When NOT To Use

- Vue 3 + Vite projects — use `vue-frontend`
- React/Svelte heavy SPAs — beyond the scope of this config

## Workflow

1. Read the local `CLAUDE.md` for stack, constraints, and target browsers.
2. Load the relevant reference:
   - `references/security.md` — CSP, XSS prevention, CORS, authentication, OWASP
   - `references/performance.md` — Core Web Vitals, lazy loading, caching, bundle optimization
3. Identify the rendering model (SSR, SPA, hybrid, static).
4. Check existing patterns before introducing new approaches.

## Guardrails

### Security (non-negotiable)
- Never use `innerHTML` with user-supplied data — use `textContent` or sanitize.
- Always set `Content-Security-Policy` headers — start strict, relax only as needed.
- Use `HttpOnly`, `Secure`, `SameSite=Strict` on all auth cookies.
- Validate and sanitize all user input on the server side — client validation is UX only.
- Escape template output by default — use raw/unescaped only with explicit justification.
- Never store secrets, tokens, or API keys in frontend code or localStorage.
- Use CSRF tokens for all state-changing requests.
- Set `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`.

### Performance
- Set a performance budget: <200KB JS (compressed), <3s LCP on 3G.
- Prefer server-rendered HTML with progressive enhancement over client-heavy SPA.
- Lazy-load images, iframes, and below-fold content.
- Use `async` or `defer` for all non-critical scripts.
- Minimize third-party scripts — each one is a performance and security liability.
- Use native browser APIs over libraries when coverage is sufficient.
- Prefer CSS for animations over JS.

### Accessibility
- Use semantic HTML (`<nav>`, `<main>`, `<article>`, `<button>`) — not `<div>` for everything.
- Every `<img>` has `alt` text; decorative images use `alt=""`.
- All interactive elements are keyboard-accessible.
- Color is never the sole indicator of state.
- Test with a screen reader for non-trivial UI changes.

### Architecture
- Prefer progressive enhancement: works without JS, better with JS.
- Keep JS small and focused — question every dependency.
- Prefer htmx, Alpine.js, or vanilla JS over React/Vue for content-driven apps.
- Use React/Vue/Svelte only when the UI complexity justifies the framework weight.
- Separate concerns: structure (HTML), presentation (CSS), behavior (JS).
