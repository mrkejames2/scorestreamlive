# M16-C — Security & Tenant Hardening

M16-C applies the established M15 authorization model consistently to older
match-day APIs without changing the deliberate public Overlay contract.

## Scope
- Authenticate Player, ScoringEvent, GameClock, and GameLifecycle APIs.
- Enforce Team/Game Club ownership plus role/assignment authorization.
- Return not-found for inaccessible direct-ID resources.
- Preserve logged-out public Overlay state and public Team-logo delivery.
- Reject cross-origin browser mutations when an Origin header is supplied.
- Fail production startup for insecure session-cookie, default DB-password,
  or wildcard Socket.IO CORS configuration.
- Add conservative response security headers.
- Disable the legacy global `test:broadcast` Socket.IO handler in production.
- Preserve M16-A authoritative recovery and M16-B game-room isolation.

## Database
No Alembic migration. Expected head remains `20260902_0013`.

## Non-goals
OAuth, MFA, SSO, public registration, password reset, CAPTCHA, WAF, Redis,
JWT/session rewrites, new RBAC frameworks, frontend rewrites, or new features.
