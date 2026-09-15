# M18-J — Final M18 Customer / Production Release Readiness Gate

## Purpose

M18-J is the final local/pre-production release gate for cumulative M18. It does not deploy production and does not enable live Stripe payments.

The release question is:

> Is cumulative M18 safe to merge into `main` and allow Render to deploy over the existing ScoreStreamLive production system while preserving existing production data and keeping real Stripe payments disabled?

## Scope

M18-J intentionally introduces no customer feature, model, API route, UI, billing-domain redesign, entitlement redesign, or Stripe redesign. It should introduce no Alembic migration unless a genuine defect is discovered during validation.

Expected Alembic head:

    20260915_0026

Local validation base URL:

    http://127.0.0.1:8000

Use Docker Compose service names (`app`, `postgres`) rather than hard-coding container names.

## Required initial production configuration

Before merging cumulative M18 to `main`, Render production configuration must be reviewed and must conceptually resolve to:

    APP_ENV=production
    PUBLIC_BASE_URL=https://<production-domain>
    BILLING_PROVIDER=stripe
    BILLING_LIVE_ENABLED=false
    PUBLIC_CHECKOUT_ENABLED=false

A Stripe live secret key must not be used while `BILLING_LIVE_ENABLED=false`.

Live payment enablement is explicitly outside M18-J.

## Release sequence

1. Complete M18-J local/pre-production automated validation.
2. Complete M18-J human acceptance.
3. Clean temporary artifacts.
4. Commit and push M18-J.
5. Record deployment identities:
   - `PRE_M18_COMMIT=<known-good production/main SHA>`
   - `M18_RELEASE_COMMIT=<final cumulative M18 SHA>`
6. Create/verify a production PostgreSQL backup or snapshot.
7. Capture the pre-deployment production data baseline.
8. Merge cumulative M18 to `main`.
9. Allow Render to build/deploy from the changed `main`.
10. Startup runs Alembic migrations in place.
11. Verify Alembic current is `20260915_0026`.
12. Perform post-deployment production acceptance.
13. Capture the post-deployment production data baseline and compare it with the pre-deployment baseline.

M18-J PASS is not production acceptance. Production acceptance can only occur after Render deploys the cumulative M18 release.

## Production database preservation policy

The existing production PostgreSQL database must migrate in place. Do not recreate the production database as part of M18 deployment.

Before `main` is updated:

- create/verify a recoverable production database backup/snapshot;
- record the current Alembic revision;
- record user count;
- record club count;
- record team count;
- record game count;
- record scoring-event count;
- retain the baseline output with deployment records.

After deployment, collect the same baseline and compare it with the pre-deployment values. Count changes must be explained by expected production activity or migration behavior.

The baseline helper is read-only. Because historical model/table naming can differ, it discovers candidate tables from PostgreSQL metadata and reports `N/A` rather than guessing when a logical entity cannot be resolved.

## Migration safety inspection

`scripts/regression/final_m18_release_gate.sh` statically inspects Alembic upgrade sections for suspicious destructive operations including:

- `drop_table`
- `drop_column`
- `TRUNCATE`
- `DELETE`
- `DROP TABLE`
- `DROP COLUMN`
- destructive/raw `ALTER` patterns

Downgrade-only destructive operations are not treated as upgrade failures.

This inspection is an automated safety gate, not proof that a migration is safe. Any flagged upgrade operation requires human review before deployment.

## Preflight

Run locally from the repository root:

    sudo env \
      BASE_URL=http://127.0.0.1:8000 \
      VALIDATION_SCOPE=release \
      ./scripts/production_m18j_preflight.sh

The preflight is deliberately non-deploying. It validates repository/runtime readiness and prints the production deployment checklist.

For the production baseline, run the baseline helper in an environment that can access the production PostgreSQL database, supplying `DATABASE_URL` if it is not already present:

    DATABASE_URL='<production-postgres-url>' \
      ./scripts/production_m18j_baseline.sh pre

After deployment:

    DATABASE_URL='<production-postgres-url>' \
      ./scripts/production_m18j_baseline.sh post

Do not place production credentials in Git or committed output.

## Automated validation

Run:

    sudo env \
      BASE_URL=http://127.0.0.1:8000 \
      VALIDATION_SCOPE=release \
      ./scripts/validate_m18j.sh

Expected high-level result:

    ========================================
    M18-J Final M18 Release Readiness Gate
    ========================================
    PASS: cumulative M18 validation
    PASS: migration chain terminates at 20260915_0026
    PASS: no new M18-J migration
    PASS: production data baseline capability
    PASS: production data preservation policy
    PASS: destructive migration safety inspection
    PASS: billing live mode disabled
    PASS: public checkout launch gate available
    PASS: Stripe live/test safety enforcement
    PASS: production HTTPS requirement
    PASS: production backup requirement
    PASS: deployment commit identity procedure
    PASS: deployment runbook
    PASS: application rollback procedure
    PASS: database recovery procedure
    PASS: production acceptance checklist

    M18-J Final M18 Release Readiness Gate: PASS

## Post-deployment production acceptance

### Infrastructure

- Render deployment completed successfully.
- `/health/live` passes.
- `/health/ready` passes.
- Alembic current is `20260915_0026`.

### Existing production data

- Existing login works.
- Existing club exists.
- Existing teams exist.
- Existing games/history exist.
- Existing rosters/data remain.
- Existing configuration remains.
- Pre/post baseline counts have been compared and any differences are understood.

### Operational behavior

- Create/open team.
- Open an existing game.
- Create a test game where entitled.
- Start/pause/reset/use the game clock.
- Record scoring.
- Verify overlay.
- Verify socket/live updates.
- Complete the test game.

### Billing and branding safety

- Billing page does not crash for pre-M18 production users.
- No accidental subscription is created.
- No accidental checkout occurs.
- Branding page behaves safely.
- `GET /api/public/checkout/plans` returns `[]` while public checkout is disabled.
- `POST /api/public/checkout` returns HTTP 503 while public checkout is disabled.
- No live Stripe charge is attempted.

## Rollback / recovery

### Application/code failure

1. Stop further release changes.
2. Preserve logs/evidence.
3. Identify `PRE_M18_COMMIT`.
4. Redeploy the previous known-good application version.
5. Re-run health and critical-path acceptance checks.

### Database/data corruption

Do **not** blindly run an Alembic downgrade in production.

1. Stop.
2. Preserve logs, database state, and other evidence where practical.
3. Prevent additional application writes if necessary.
4. Restore the verified pre-M18 PostgreSQL backup/snapshot using the production platform's recovery procedure.
5. Redeploy `PRE_M18_COMMIT`.
6. Verify health and production data.
7. Investigate before attempting M18 deployment again.

## Human acceptance gate

Do not commit/push M18-J merely because automated validation passes.

Required sequence:

    M18-J IMPLEMENTATION = PASS
    M18-J HUMAN ACCEPTANCE = PASS

Only then clean temporary artifacts, stage, commit, push, and prepare the cumulative M18 merge to `main`.
