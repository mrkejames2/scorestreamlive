# M16-E — Production Operations & Final Release Gate

## Objective

Close M16 Production MVP Hardening with deterministic startup, production-safe configuration, operational recovery checks, and one cumulative release gate. M16-E adds no product feature and no schema migration.

## Production runtime contract

- PostgreSQL/server state remains authoritative. Socket.IO remains notification transport.
- `entrypoint.sh` runs `alembic upgrade head` automatically before Uvicorn.
- Alembic head remains `20260902_0013`.
- `M15_BOOTSTRAP_ENABLED` defaults to `false` and remains false in production steady state.
- Render deploys `main`; no Render shell step is required.
- Container runtime remains non-root.
- Render and container health checks continue to use `/health/live`.
- Production database SSL remains required.

## Production security boundary

M16-C production startup checks remain fail-closed. M16-E keeps the explicit `DB_*` Render database configuration and strengthens origin handling without relying on reverse-proxy request scheme reconstruction.

For authenticated browser mutations in production, the incoming `Origin` must match an explicit HTTPS origin in `SOCKET_CORS_ORIGINS`. This avoids trusting client-supplied forwarding headers and remains compatible with Render's reverse proxy. Development/local requests retain the existing request-origin comparison.

The deliberate public boundary is unchanged: logged-out public Overlay state and Team logos remain public; Control Center and privileged mutation APIs remain authenticated/authorized.

## Validation

M16-E adds domain 25:

`Production Operations/Final Release Gate`

Local FAST and FULL should each report 25/25 PASS. The existing `release` scope may include its separate Recovery domain in addition to the 25 cumulative milestone domains.

The M16-E domain is non-destructive in production. It validates startup/configuration/release invariants. Existing M16-A through M16-D domains continue to validate state recovery, Socket.IO isolation, security/tenant boundaries, and operator/data-integrity behavior.

## Required local release sequence

1. M16-E Local FAST — PASS.
2. M16-E Local FULL — PASS.
3. Deliberate local failure/recovery exercise — PASS.
4. M16-E Local Human Acceptance — PASS.
5. Confirm clean working tree, commit, and push M16-E.
6. Merge the cumulative M16-E branch into `main` only after local approval.
7. Render automatically deploys `main` and runs Alembic automatically.
8. Production FAST — PASS.
9. Production FULL — PASS.
10. Production Human Acceptance — PASS.

## Deliberate local failure/recovery exercise

Use a disposable/local game, never synthetic production data.

1. Begin a match and make score, clock, and lifecycle changes.
2. Verify a logged-out Overlay reflects current authoritative state.
3. Refresh/reconnect Control Center and Overlay; verify convergence.
4. Restart the application container while PostgreSQL remains intact.
5. Reload Control Center and Overlay.
6. Verify score, clock/lifecycle phase, scoring history, and corrections reconstruct from server state.
7. Make one post-recovery score correction and verify Overlay convergence.
8. Confirm no duplicate score event or duplicate lifecycle transition was created.

## Production human acceptance

After Render deployment:

- Login/logout and navigation work.
- Club/role/tenant authorization remains correct.
- Team/Game management works for authorized users.
- Control Center loads and reaches LIVE authoritative state.
- Logged-out public Overlay loads.
- Goal, known/unknown scorer, correction, and deletion work.
- Clock start/pause/resume/configuration works.
- Lifecycle transitions and destructive confirmations work.
- Refresh/reconnect reconverges to authoritative state.
- Cross-Club/direct-ID access remains denied/masked.
- Production security headers are present.
- Diagnostic `test:broadcast` remains disabled in production.

## Completion declaration

Only after Production FAST, Production FULL, and Production Human Acceptance all pass:

```text
M16 PRODUCTION VALIDATION = PASS
M16 PRODUCTION HUMAN ACCEPTANCE = PASS
M16 PRODUCTION MVP HARDENING = COMPLETE
```

## Non-goals

No Redis/NATS/Kafka, Kubernetes, horizontal-scaling work, new observability platform, auth redesign, billing, new sports/features, UI redesign, offline mode, or broad performance work is introduced in M16-E.
