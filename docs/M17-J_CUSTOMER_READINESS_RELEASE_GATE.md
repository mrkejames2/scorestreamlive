# M17-J — Customer Readiness & Production Release Gate

## Objective

Certify the cumulative M17 product as a customer-ready production release
candidate without introducing another product feature or changing the
authoritative-state architecture.

## Scope

M17-J is intentionally release-focused.

It adds:

- current customer-facing repository documentation
- a production release checklist
- cumulative validation domain 35
- a final M17 validation wrapper
- explicit local and production promotion criteria

It does not add:

- database schema changes
- Alembic migrations
- new models
- new product state
- Socket.IO protocol or room changes
- timer/scoring/lifecycle redesign
- deployment topology changes
- Redis, Kafka, NATS, RabbitMQ, Celery, or Kubernetes

## Customer readiness journey

The release candidate must support a coherent journey through the already
implemented product:

```text
Authenticate
  -> Club membership
  -> users / roles
  -> Team
  -> roster
  -> Game
  -> pregame setup
  -> Control
  -> public Overlay
  -> scoring / clock / lifecycle
  -> post-game summary
  -> Game library / recovery
```

M17-J does not duplicate those domain implementations. Existing cumulative
regression domains and Human Acceptance certify them.

## Protected architecture

```text
PostgreSQL = authoritative persistent state
REST       = durable mutation boundary
Socket.IO  = committed-state notification transport
Club       = tenant boundary
```

The Overlay remains a public read/presentation surface. Control and private APIs
remain authenticated and authorized.

## Validation domain 35

M17-J adds:

```text
Customer Readiness & Production Release Gate
```

The domain verifies:

- current M17 release documentation exists
- stale historical milestone status is no longer presented as current
- all M17-A through M17-I cumulative validation domains remain registered
- M17-J is registered as domain 35
- Render remains configured to deploy `main`
- production startup/migration/bootstrap contracts remain present
- liveness, readiness, and release identity endpoints are available
- production checks are non-destructive
- M17-J introduces no release-specific migration or distributed infrastructure

## Local release gates

Before committing M17-J:

```text
FAST              35 / 35 PASS
FULL              35 / 35 PASS
Human Acceptance  PASS
```

Human Acceptance should verify the customer journey using the local environment.

## Production promotion

After local gates pass:

1. commit and push the M17-J branch
2. merge the cumulative M17-J branch to `main`
3. push `main`
4. allow Render to deploy
5. verify `/info` identifies the running release
6. run production FAST
7. run production FULL
8. complete production Human Acceptance

Production validation must be non-destructive.

## Production completion declaration

Do not declare:

```text
M17 PRODUCTION COMPLETE
```

until the Render-deployed release has passed production FAST, production FULL,
and production Human Acceptance.

A final documentation-only closeout may then record the deployed release and
acceptance evidence.

## Human Acceptance

Verify the already implemented product as a customer would:

1. authenticate successfully
2. navigate account and Club surfaces
3. inspect/manage a Team and roster
4. inspect/create/manage a Game as authorized
5. open pregame setup
6. launch Control
7. open the public Overlay
8. exercise scoring, clock, and lifecycle behavior using approved local test data
9. verify post-game summary/broadcast behavior
10. verify Game library/recovery behavior
11. verify Director support diagnostics
12. confirm no unexpected cross-Club visibility or private/public boundary issue
13. confirm the cohesive M17-H product theme remains intact

## Release rollback / incident response

If a production gate fails, do not declare release completion. Capture:

- deployed release identity
- request ID when applicable
- failed validation run/log
- `/health/live`
- `/health/ready`
- `/info`
- Director diagnostics when authorized

Then follow `docs/operations/INCIDENT_TRIAGE.md` and fix forward or roll back
through the established Git/Render release process.
