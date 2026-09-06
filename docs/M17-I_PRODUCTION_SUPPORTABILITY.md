# M17-I — Production Supportability

## Objective

Make ScoreStreamLive production incidents diagnosable without changing the
authoritative-state architecture established through M16 and M17-H.

M17-I adds operational identity, request correlation, safe diagnostics, and a
support runbook. It adds no product feature and no database migration.

## Runtime contract

- PostgreSQL remains authoritative product state.
- Socket.IO remains notification transport.
- `/health/live` remains dependency-free liveness.
- `/health/ready` remains PostgreSQL-backed readiness.
- Render and Docker continue to use `/health/live`.
- Production startup remains fail-closed under the existing security checks.
- Diagnostics are read-only.
- Production validation creates no synthetic data.

## Deployment identity

`APP_VERSION` remains the human software version.

`APP_RELEASE` identifies the exact deployment. Resolution order is:

1. `APP_RELEASE` when explicitly configured.
2. `RENDER_GIT_COMMIT` when supplied by Render.
3. `unknown` as a safe fallback.

`/info`, `/`, response headers, startup logs, and HTTP request logs expose the
release identifier. No secret configuration is exposed.

## HTTP request correlation

Every HTTP request receives a server-generated UUID correlation identifier.

Normal responses include:

- `X-Request-ID`
- `X-ScoreStreamLive-Release`

Structured request logs inherit the same request ID through an async-safe
`ContextVar`. Unhandled request exceptions are logged with the same correlation
context and are re-raised so FastAPI error semantics remain unchanged.

## Logging safety

The JSON logger preserves searchable operational identifiers while redacting
obviously sensitive extra fields such as passwords, tokens, cookies,
authorization values, and secrets.

Existing code should still avoid logging secrets in messages. Formatter
redaction is defense-in-depth, not permission to log credentials.

## Director support diagnostics

`GET /api/support/diagnostics`

The endpoint requires an authenticated Club Director and returns a read-only
snapshot containing:

- application name
- environment
- software version
- exact release identity
- server UTC time
- PostgreSQL connectivity and latency
- Team-logo storage writability
- email delivery mode and configured/not-configured state
- Socket.IO origin policy classification and configured origin count
- current request ID

The endpoint does not return database credentials, SMTP credentials, cookies,
session tokens, raw environment variables, user data, cross-Club data, or
configured origin values.

## Validation

M17-I adds cumulative validation domain 34:

`Production Supportability`

The validation is read-only in both local and production mode.

## Human Acceptance

1. Open `/info` and confirm the running release can be identified.
2. Confirm a normal HTTP response includes `X-Request-ID`.
3. Find the same request ID in application logs.
4. As a Director, open/call `/api/support/diagnostics`.
5. Confirm database, storage, email, socket-policy, release, and server-time
   diagnostics are present.
6. Confirm logged-out access is denied.
7. Confirm Manager/Operator access is denied.
8. Confirm no credentials, cookies, tokens, or full environment are exposed.
9. Confirm Control, Overlay, scoring, clock, lifecycle, and Socket.IO behavior
   remain unchanged.

## Non-goals

M17-I does not add Redis, Kafka, NATS, RabbitMQ, Celery, Kubernetes, an external
observability vendor, a telemetry database, an audit database, a schema
migration, billing, new sports, UI redesign, or Socket.IO architecture changes.
