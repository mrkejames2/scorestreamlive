# ScoreStreamLive Production Release Checklist

Use this checklist for the M17-J production promotion.

## Before local release gate

- [ ] Current branch is `milestone/m17-j-customer-readiness-release-gate`
- [ ] Branch descends from completed M17-I commit `a6a766d`
- [ ] Working tree contains only intentional M17-J changes
- [ ] No transfer ZIP, `__pycache__`, `.pyc`, or validation-run artifacts are staged
- [ ] No M17-J Alembic migration exists
- [ ] No new runtime/distributed infrastructure was introduced

## Local release candidate

- [ ] Application is healthy locally
- [ ] `/health/live` succeeds
- [ ] `/health/ready` succeeds
- [ ] `/info` returns application, version, environment, and release identity
- [ ] M17-J FAST is 35 / 35 PASS
- [ ] M17-J FULL is 35 / 35 PASS
- [ ] M17-J Human Acceptance is PASS

## Production configuration

Confirm in the deployment environment without printing secrets:

- [ ] `APP_ENV=production`
- [ ] `M15_BOOTSTRAP_ENABLED=false`
- [ ] production database variables are configured
- [ ] production database credentials are not development defaults
- [ ] secure authentication/session configuration is enabled
- [ ] Socket.IO origins are explicit HTTPS origins and not wildcard
- [ ] email mode/configuration matches intended production behavior
- [ ] Team logo storage is configured/persistent as intended
- [ ] release identity can resolve the deployed commit
- [ ] no secret value is copied into release notes or validation output

## Git promotion

- [ ] M17-J branch committed
- [ ] M17-J branch pushed
- [ ] M17-J branch working tree clean
- [ ] `main` updated before merge
- [ ] cumulative M17-J merged to `main`
- [ ] `main` pushed to GitHub

## Render deployment

- [ ] Render deployment triggered from `main`
- [ ] Docker build succeeds
- [ ] entrypoint Alembic upgrade succeeds
- [ ] application starts
- [ ] Render `/health/live` health check succeeds
- [ ] deployment reaches healthy/running state

## Production identity and health

- [ ] `/health/live` succeeds
- [ ] `/health/ready` succeeds
- [ ] `/info` succeeds
- [ ] deployed release identity matches the intended Git release
- [ ] normal response includes `X-Request-ID`
- [ ] normal response includes `X-ScoreStreamLive-Release`
- [ ] Director support diagnostics are available to an authorized Director
- [ ] logged-out support diagnostics access remains denied

## Production validation

Production validation must not create synthetic customer data.

- [ ] production FAST is 35 / 35 PASS
- [ ] production FULL is 35 / 35 PASS
- [ ] failed logs, if any, are reviewed before rerunning

## Production Human Acceptance

Using approved existing production data:

- [ ] login/account navigation
- [ ] Club/role behavior
- [ ] Team and roster surfaces
- [ ] Game library
- [ ] Game setup
- [ ] Control
- [ ] public Overlay
- [ ] scoring/corrections
- [ ] clock/lifecycle
- [ ] post-game summary/broadcast
- [ ] recovery/resume behavior
- [ ] cohesive theme/branding
- [ ] Director diagnostics
- [ ] tenant/private-public boundaries

## Completion

Only after every required production gate passes:

- [ ] record deployed release/commit
- [ ] record production FAST run/result
- [ ] record production FULL run/result
- [ ] record production Human Acceptance PASS
- [ ] update milestone status to `M17 PRODUCTION COMPLETE`
- [ ] retain a clean `main` baseline

## Failure path

If any production gate fails:

1. stop the release declaration
2. capture release identity and request ID when applicable
3. preserve validation logs
4. check `/health/live`, `/health/ready`, and `/info`
5. use Director diagnostics when authorized
6. follow `docs/operations/INCIDENT_TRIAGE.md`
7. fix forward or roll back using the established Git/Render process
8. rerun the required production gates
