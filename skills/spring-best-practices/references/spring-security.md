# Spring Security Reference

## SecurityFilterChain (Spring Security 5.7+)

Use `SecurityFilterChain` beans, not `WebSecurityConfigurerAdapter` (deprecated).

```java
@Bean
public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(AbstractHttpConfigurer::disable)          // only for stateless REST APIs
        .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/actuator/health").permitAll()
            .requestMatchers("/api/public/**").permitAll()
            .anyRequest().authenticated()
        )
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
        .build();
}
```

## JWT Authentication

- Store JWT secret in environment variable or secrets manager, never in code or config files.
- Validate: signature, expiry (`exp`), issuer (`iss`), audience (`aud`) if applicable.
- Use short-lived access tokens (15-60 min) + refresh tokens (store refresh token server-side for revocation).
- Set `Authorization: Bearer <token>` header; do not put tokens in URL parameters.
- Use `jjwt` or `nimbus-jose-jwt` libraries; do not implement JWT manually.

## CORS Configuration

```java
@Bean
public CorsConfigurationSource corsConfigurationSource() {
    CorsConfiguration config = new CorsConfiguration();
    config.setAllowedOriginPatterns(List.of("https://*.yourdomain.com"));
    config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE"));
    config.setAllowedHeaders(List.of("Authorization", "Content-Type"));
    config.setAllowCredentials(true);
    UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
    source.registerCorsConfiguration("/**", config);
    return source;
}
```

Never use `allowedOrigins("*")` together with `allowCredentials(true)` - browsers block this.

## CSRF

- **Disable CSRF** for stateless REST APIs (JWT or API key auth, no session cookies).
- **Keep CSRF enabled** for server-rendered apps with session cookies.
- If CSRF is disabled, document why in the security config class.

## Method Security

Enable with `@EnableMethodSecurity` (replaces `@EnableGlobalMethodSecurity`).

```java
@PreAuthorize("hasRole('ADMIN')")
public void deleteUser(Long id) { ... }

@PostAuthorize("returnObject.ownerId == authentication.name")
public Report getReport(Long id) { ... }

@PreAuthorize("@mySecurityService.canAccess(#resourceId, authentication)")
public Resource getResource(Long resourceId) { ... }
```

Use SpEL with a `@Service` bean for complex rules (`@mySecurityService.canAccess(...)`) rather than inline conditions.

## Password Encoding

Always use `BCryptPasswordEncoder` or `Argon2PasswordEncoder`. Never store plain-text or MD5/SHA passwords.

```java
@Bean
public PasswordEncoder passwordEncoder() {
    return new BCryptPasswordEncoder(12);
}
```

## Actuator Security

Expose only what is necessary. Separate actuator security from API security with a dedicated `SecurityFilterChain` on `/actuator/**`.

```java
@Bean
@Order(1)
public SecurityFilterChain actuatorSecurity(HttpSecurity http) throws Exception {
    return http
        .securityMatcher("/actuator/**")
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/actuator/health", "/actuator/info").permitAll()
            .anyRequest().hasRole("OPS")
        )
        .build();
}
```
