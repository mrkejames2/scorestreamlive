# ScoreStreamLive — Deployment

## Deployment flow

```text
Local Ubuntu VM
  -> Docker Compose
  -> milestone branch
  -> local FAST
  -> local FULL
  -> Human Acceptance
  -> Git checkpoint
  -> merge final cumulative milestone branch to main
  -> GitHub
  -> Render deployment
  -> production FAST
  -> production FULL
  -> production Human Acceptance
```

## Local startup

Typical:

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
sudo docker compose logs app --tail=100
```

Do not use `docker compose down -v` during ordinary validation. Persistent
volumes contain PostgreSQL data and Team logo uploads.

## Database migration check

```bash
sudo docker compose exec app alembic current
```

The container entrypoint runs `alembic upgrade head` before application startup.
Always inspect the repository migration chain rather than relying on an old
documented revision number.

## Local M17-J validation

FAST:

```bash
sudo BASE_URL="http://localhost:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_m17j.sh
```

FULL:

```bash
sudo BASE_URL="http://localhost:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=full \
VALIDATION_OUTPUT=full \
./scripts/validate_m17j.sh
```

Expected cumulative result:

```text
35 / 35 domains PASS
OVERALL PASS
```

Local Human Acceptance is required before the M17-J branch is committed and
promoted.

## Git release discipline

Before checkpoint:

```bash
git status
git diff --cached --stat
git diff --cached
git diff --cached --check
```

Remove downloaded ZIP and other transfer artifacts before committing unless
they are intentional repository content.

## Promotion to main

After local M17-J FAST, FULL, and Human Acceptance pass and the milestone branch
is committed/pushed:

```bash
git switch main
git pull --ff-only origin main

git merge --no-ff milestone/m17-j-customer-readiness-release-gate \
  -m "Merge Milestone 17 customer readiness release"

git push origin main
```

Render is configured to deploy `main`.

## Production

Production URL:

```text
https://scorestreamlive.onrender.com
```

Render startup is expected to run the Docker image and Alembic upgrade
automatically. Production bootstrap remains disabled unless explicitly enabled;
the production release checklist requires it to be false.

## Verify deployment identity

After Render reports a successful deployment:

```bash
curl -sS https://scorestreamlive.onrender.com/health/live
echo

curl -sS https://scorestreamlive.onrender.com/health/ready
echo

curl -sS https://scorestreamlive.onrender.com/info
echo
```

Use `/info` and `X-ScoreStreamLive-Release` to confirm which release is actually
running before accepting production.

## Production M17-J validation

FAST:

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" \
VALIDATION_MODE=production \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_m17j.sh
```

FULL:

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" \
VALIDATION_MODE=production \
VALIDATION_SCOPE=full \
VALIDATION_OUTPUT=full \
./scripts/validate_m17j.sh
```

Production mode must remain non-destructive. Do not create synthetic Clubs,
users, Teams, Games, scoring events, or other customer data merely to satisfy a
release gate.

## Production Human Acceptance

After production FAST/FULL pass, verify the real customer journey using approved
existing data:

- authentication and account navigation
- Team and roster management
- Game library and Game setup
- Control
- public Overlay
- scoring and correction behavior
- clock and lifecycle behavior
- post-game summary
- Director diagnostics
- logout/re-entry/recovery behavior as appropriate

Do not declare M17 production complete until production Human Acceptance passes.

## Operational support

Use:

- `/health/live` for process liveness
- `/health/ready` for database-backed readiness
- `/info` for release identity
- `/api/support/diagnostics` as an authenticated Director for safe diagnostics
- `docs/operations/INCIDENT_TRIAGE.md` during production incidents

See `docs/operations/PRODUCTION_RELEASE_CHECKLIST.md` for the release sequence.
