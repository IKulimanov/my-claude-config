# Web Performance

## Core Web Vitals Targets

| Metric | Good | What it measures |
|--------|------|-----------------|
| LCP (Largest Contentful Paint) | < 2.5s | Loading speed |
| INP (Interaction to Next Paint) | < 200ms | Responsiveness |
| CLS (Cumulative Layout Shift) | < 0.1 | Visual stability |

## Loading Strategy

### Critical Rendering Path
1. Inline critical CSS (above-the-fold styles) in `<head>`.
2. Defer non-critical CSS with `media="print" onload="this.media='all'"`.
3. Use `async` for analytics/tracking scripts.
4. Use `defer` for app scripts that depend on DOM.
5. Preload key resources: `<link rel="preload" href="font.woff2" as="font" crossorigin>`.

### JavaScript Budget
- Target: <200KB JS transferred (compressed) for the entire page.
- Audit with: `npx bundlephobia <package>` before adding dependencies.
- Tree-shake unused code — use ES modules.
- Code-split by route for SPAs.

### Images
- Use `<img loading="lazy">` for below-fold images.
- Use modern formats: WebP (95%+ support), AVIF (growing support).
- Always set `width` and `height` to prevent layout shift.
- Use `<picture>` with `srcset` for responsive images.
- Compress aggressively — most images can lose 60-80% size without visible quality loss.

## Caching

### HTTP Cache Headers
```
# Immutable assets (hashed filenames)
Cache-Control: public, max-age=31536000, immutable

# HTML pages
Cache-Control: no-cache
ETag: "abc123"

# API responses
Cache-Control: private, max-age=0, must-revalidate
```

### Service Worker (for offline/PWA)
- Cache static assets with cache-first strategy.
- Use network-first for API calls.
- Keep the service worker simple — complexity leads to stale content bugs.

## Rendering Patterns

| Pattern | Best for | Trade-off |
|---------|----------|-----------|
| SSR (Server-Side Rendering) | Content sites, SEO | Server load, TTFB |
| SSG (Static Site Generation) | Blogs, docs, marketing | Rebuild on content change |
| CSR (Client-Side Rendering) | Dashboards, apps | Poor initial load, SEO issues |
| Progressive Enhancement | Most web apps | Requires discipline |

**Default recommendation:** SSR with progressive enhancement. Use CSR/SPA only when the interactivity justifies it.

## Go-Specific Web Performance

### Template Rendering
- Parse templates once at startup with `template.Must(template.ParseGlob(...))`.
- Use `template.FuncMap` for reusable template helpers.
- Enable gzip compression via middleware.

### Static File Serving
```go
// Embed static files for single-binary deployment
//go:embed static/*
var staticFS embed.FS

// Serve with cache headers
func staticHandler() http.Handler {
    fs := http.FileServer(http.FS(staticFS))
    return http.StripPrefix("/static/", cacheControl(fs))
}
```

### Response Optimization
- Use `http.ServeContent` for proper ETag and conditional request support.
- Stream large responses instead of buffering.
- Set appropriate `Content-Type` headers.

## Monitoring

- Measure Real User Metrics (RUM) with `PerformanceObserver` API.
- Set alerts on Core Web Vitals regressions.
- Test with Lighthouse CI in your pipeline.
- Test on real slow devices and connections, not just dev machines.
