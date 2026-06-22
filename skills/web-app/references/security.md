# Web Security

## OWASP Top 10 Awareness

Every web application must address:
1. **Injection** — parameterize queries, sanitize input, use ORM safely
2. **Broken Authentication** — secure session management, MFA, rate limiting
3. **Sensitive Data Exposure** — TLS everywhere, encrypt at rest, minimize data collection
4. **XSS** — escape output, CSP, avoid innerHTML
5. **Broken Access Control** — server-side checks on every request
6. **Security Misconfiguration** — security headers, disable debug in prod
7. **CSRF** — tokens for state-changing requests, SameSite cookies

## Content Security Policy (CSP)

Start strict, relax only when needed:
```
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  font-src 'self';
  connect-src 'self';
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
```

- Never use `'unsafe-eval'` — it defeats most XSS protections.
- Use nonces (`'nonce-<random>'`) for inline scripts if unavoidable.
- Report violations: `report-uri /csp-report` or `report-to` directive.

## CORS

```go
// Only allow specific origins — never use "*" with credentials
func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        origin := r.Header.Get("Origin")
        if isAllowedOrigin(origin) {
            w.Header().Set("Access-Control-Allow-Origin", origin)
            w.Header().Set("Access-Control-Allow-Credentials", "true")
            w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE")
            w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        }
        if r.Method == http.MethodOptions {
            w.WriteHeader(http.StatusNoContent)
            return
        }
        next.ServeHTTP(w, r)
    })
}
```

## Cookie Security

```go
http.SetCookie(w, &http.Cookie{
    Name:     "session",
    Value:    token,
    HttpOnly: true,           // not accessible via JS
    Secure:   true,           // HTTPS only
    SameSite: http.SameSiteStrictMode,
    Path:     "/",
    MaxAge:   3600,
})
```

## XSS Prevention

1. **Escape output by default** — Go's `html/template` auto-escapes.
2. **Never use `template.HTML()` with user input** — only for trusted static content.
3. **Sanitize rich text** — use allowlist-based sanitizer (e.g., `bluemonday`).
4. **CSP as defense-in-depth** — even if you miss an escape, CSP blocks execution.

## Authentication Patterns

- Use bcrypt or argon2 for password hashing — never SHA/MD5.
- Implement rate limiting on login endpoints.
- Use short-lived JWTs (15min) + refresh tokens, or server-side sessions.
- Invalidate sessions on password change.
- Log authentication events for audit.

## Input Validation

- Validate on the server — client validation is UX, not security.
- Use allowlists over denylists.
- Validate type, length, range, and format.
- Reject unexpected fields in API payloads.
- Use parameterized queries — never concatenate user input into SQL.

## Security Headers Checklist

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: camera=(), microphone=(), geolocation=()
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
Content-Security-Policy: <see above>
```
