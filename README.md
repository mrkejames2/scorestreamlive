# ScoreStreamLive

ScoreStreamLive is a production-oriented soccer scoring, match-control, and
livestream-overlay application built with FastAPI, Socket.IO, PostgreSQL, and
Docker.

## Product capabilities

ScoreStreamLive currently provides:

- authenticated Club accounts and role-based access
- Club Director user administration
- Team creation, editing, branding, and roster management
- Game creation, library, search, filtering, and lifecycle management
- match-day setup and operator Control Center
- persistent authoritative match clock and lifecycle state
- scoring history and scoring corrections
- public broadcast overlay with Team branding
- post-game summary and broadcast scene
- account invitation, activation, recovery, and lifecycle controls
- production diagnostics, release identity, request correlation, and incident
  supportability

## Architecture

The core state contract is intentionally simple:

```text
Browser / API Client
        |
   +----+----+
   |         |
 REST     Socket.IO
   |         |
   +----+----+
        |
      FastAPI
        |
     Services
        |
 SQLAlchemy Async
        |
   PostgreSQL
```

PostgreSQL is authoritative for persistent product state. REST is the durable
mutation boundary. Socket.IO distributes committed state after successful
mutations.

The application does not depend on Redis, Kafka, NATS, RabbitMQ, Celery, or
Kubernetes.

See `docs/ARCHITECTURE.md` for the current architecture contract.

## Local development

Typical startup:

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

Useful health checks:

```bash
curl -sS http://localhost:8000/health/live
curl -sS http://localhost:8000/health/ready
curl -sS http://localhost:8000/info
```

Do not use `docker compose down -v` during ordinary development or validation;
the persistent volumes contain PostgreSQL data and uploaded Team logo files.

## Primary product surfaces

```text
/teams
/teams/{team_id}
/games
/games/{game_id}
/games/{game_id}/setup
/control/games/{game_id}
/overlay/games/{game_id}
```

The Overlay is a public broadcast surface. Control and private management APIs
remain authenticated and authorized.

## Validation

The canonical cumulative validation harness is:

```bash
sudo BASE_URL="http://localhost:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_m17j.sh
```

For the final M17 release candidate, the cumulative harness contains 35 durable
validation domains. `FULL` is required before release. Production validation is
non-destructive.

## Deployment

The release flow is:

```text
milestone branch
  -> local FAST
  -> local FULL
  -> Human Acceptance
  -> commit/push
  -> merge final cumulative milestone branch to main
  -> Render deployment
  -> production FAST/FULL
  -> production Human Acceptance
```

Render deploys the repository `main` branch.

See `docs/DEPLOYMENT.md` and
`docs/operations/PRODUCTION_RELEASE_CHECKLIST.md` before production promotion.

## Current release state

M17-A through M17-I are complete. M17-J is the Customer Readiness & Production
Release Gate. The repository must not declare M17 production complete until the
M17-J branch has passed local validation and Human Acceptance, has been promoted
to `main`, and the deployed Render release has passed production validation and
production Human Acceptance.
