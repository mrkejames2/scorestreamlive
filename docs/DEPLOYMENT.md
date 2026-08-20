# ScoreStreamLive — Deployment

## Deployment Flow

```text
Local Ubuntu VM
↓
Docker Compose
↓
local validation
↓
Git checkpoint
↓
merge final milestone branch → main
↓
GitHub
↓
Render deployment
↓
production validation
```

## Local Startup

Typical:

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
sudo docker compose logs app --tail=100
```

Do not use `docker compose down -v` during ordinary validation; persistent volumes contain PostgreSQL data and Team logo uploads.

## Migration Check

```bash
sudo docker compose exec app alembic current
```

M13 introduced no database migration. Always inspect the repository migration chain rather than relying on an old documented revision number.

## M13 Local Validation

Canonical release harness:

```bash
sudo BASE_URL="http://192.168.12.133:8000" VALIDATION_MODE=local ./scripts/validate_m13h.sh
```

Accepted local M13 result:

```text
M13-H ............... PASS   36 passed / 0 failed
M13-G cumulative .... PASS
OVERALL ............. PASS
MILESTONE 13 LOCAL RELEASE GATE = PASS
```

M13-G performs local application-container and PostgreSQL-container recovery testing. Brief connection failures while the app is restarting are expected if the retry loop subsequently restores readiness and the gate passes.

## Production

Render deploys from GitHub `main`.

Production URL:

```text
https://scorestreamlive.onrender.com
```

## M13 Production Validation

After the final M13-H branch is merged to `main`, pushed, and Render deployment completes:

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" VALIDATION_MODE=production ./scripts/validate_m13h.sh
```

Production mode must skip local-only Docker/container restart operations while still validating production-safe persistent behavior and the cumulative release chain.

M13 is not fully complete until production M13-H passes.

## Team Logo Persistence

Local Docker Compose uses persistent storage for Team logo uploads. PostgreSQL stores Team `logo_url` metadata; image bytes are outside PostgreSQL.

## Git Release Discipline

Before checkpoint:

```bash
git status
git diff --cached --stat
git diff --cached --check
```

Remove downloaded ZIP/README transfer artifacts before committing unless intentionally repository content.

After production PASS, delete merged M13 milestone branches and leave a clean `main` baseline.

## Known Deferred Maintenance

Validation/test data can accumulate significantly. Safe validation-data cleanup and a deliberate fresh-application data reset are tracked in `BACKLOG.MD`; do not improvise destructive cleanup during a release.
