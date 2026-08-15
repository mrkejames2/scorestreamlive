# ScoreStreamLive — Deployment

## Deployment Flow

```text
Local Ubuntu VM
 ↓
Docker Compose
 ↓
Validation
 ↓
Git
 ↓
GitHub
 ↓
Render
 ↓
PostgreSQL migration
 ↓
Production validation
```

## Local Startup

Typical:

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
sudo docker compose logs app --tail=100
```

## Migration Check

Local:

```bash
sudo docker compose exec app alembic current
```

Current M7 head:

```text
20260813_0004
```

## Local Validation

Current final milestone harness:

```bash
sudo BASE_URL="http://<LOCAL-IP>:8000" ./scripts/validate_m7.sh
```

Expected:

```text
M7 VALIDATION PASSED
Failed: 0
```

M6 regression:

```bash
sudo BASE_URL="http://<LOCAL-IP>:8000" ./scripts/validate_m6.sh
```

Expected:

```text
57 passed
0 failed
```

## Git

Before push:

```bash
git status
git diff --stat
git diff --check
git diff
```

## Production

Render deploys from GitHub.

Production URL:

```text
https://scorestreamlive.onrender.com
```

## Production Validation

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" ./scripts/validate_m7.sh
```

M7 production result:

```text
127 passed
0 failed
```

Standalone M6 regression:

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" ./scripts/validate_m6.sh
```

Result:

```text
57 passed
0 failed
```

## Socket.IO Transient Retry

The final M7 wrapper allows one retry of the M6 regression harness after a short pause when the first production Socket.IO connection attempt fails.

A second failure still fails the milestone validation.

This handles observed transient Render/Socket.IO connection timing without masking persistent regressions.

## Docker Compose Warning

The obsolete top-level Compose `version` warning is known and non-blocking.

It is deferred maintenance and should not be mixed into feature milestones unless deliberately scheduled.
