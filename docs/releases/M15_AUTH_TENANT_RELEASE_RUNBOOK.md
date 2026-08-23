# M15 Authentication & Tenant Release Runbook

M15 establishes authenticated, isolated ScoreStreamLive Club environments.

## Data ownership model

A User belongs to one Club in M15. Teams and Games belong to that Club.
Director users see the Club environment. Managers see assigned Teams and
Games involving those Teams. Operators see explicitly assigned Games. Public
broadcast overlays remain read-only and unauthenticated.

Two different Clubs may independently create Teams with identical names.
There is no shared global Team catalog in M15.

## Database migration sequence

The M15 schema chain is:

1. `20260824_0010_create_users_and_sessions.py`
2. `20260824_0011_add_clubs_and_user_membership.py`
3. `20260824_0012_add_resource_club_scope_and_assignments.py`

Apply and verify:

```bash
sudo docker compose exec app alembic upgrade head
sudo docker compose exec app alembic current
```

Expected head:

```text
20260824_0012 (head)
```

## First User bootstrap

Create the initial authenticated User:

```bash
sudo docker compose exec app python -m app.cli.bootstrap_user
```

Use a unique email and strong password.

## First Club bootstrap

Assign the initial User as Director of a Club:

```bash
sudo docker compose exec app python -m app.cli.bootstrap_club
```

The selected User becomes `DIRECTOR`.

## Existing-resource claim

For an upgrade from pre-M15 data, claim legacy Teams and Games into the
Director's Club:

```bash
sudo docker compose exec app python -m app.cli.claim_club_resources
```

Run this only after migration 0012 and Club bootstrap.

## Local release validation

FAST:

```bash
sudo BASE_URL="http://127.0.0.1:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=fast \
VALIDATION_OUTPUT=full \
./scripts/validate_m15e.sh
```

FULL:

```bash
sudo BASE_URL="http://127.0.0.1:8000" \
VALIDATION_MODE=local \
VALIDATION_SCOPE=full \
VALIDATION_OUTPUT=full \
./scripts/validate_m15e.sh
```

Local M15-E tenant-isolation validation creates disposable fixtures whose Club
names begin with `M15E-VALIDATION-` and whose email addresses use
`example.invalid`. The test cleans those records when it exits.

## Production validation

Production validation is read-only with respect to tenant fixtures. It must
never create synthetic Clubs or Users.

```bash
sudo BASE_URL="https://scorestreamlive.onrender.com" \
VALIDATION_MODE=production \
VALIDATION_SCOPE=full \
VALIDATION_OUTPUT=full \
./scripts/validate_m15e.sh
```

Production validation checks the public/authentication boundary and structural
tenant guards without creating test tenant data.

## Human acceptance release gate

Before closing M15, verify:

- Login lands on `/games`.
- Director sees `Club Admin` and can reach `/account`.
- Manager sees only assigned Teams and related Games.
- Operator sees only explicitly assigned Games.
- Logout is available throughout authenticated management pages.
- Logged-out administrative APIs reject access.
- Public Overlay works while logged out.
- Two Clubs can independently contain Teams with identical names.
- Cross-Club Team/Game direct IDs are not disclosed through authenticated
  administrative APIs.

## Rollback note

M15 migrations should not be downgraded in production merely to undo UI or
authorization behavior. Application rollback should first use the prior known
good application revision while preserving the migrated database unless a
separately reviewed database rollback plan exists.
