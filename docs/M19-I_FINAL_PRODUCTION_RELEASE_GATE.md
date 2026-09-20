# M19-I — Final Production Release Gate

M19-I is the cumulative production-readiness gate for ScoreStreamLive M19. It adds release tooling/documentation only.

Accepted M19-H base: `99aba774b48b058287f5f9aa963a6f18920d9174`
Expected Alembic head: `20260920_0031`

## Acceptance states
- M19-I LOCAL VALIDATION = PASS
- M19-I RELEASE REVIEW = PASS
- M19-I PRODUCTION PREFLIGHT = PASS
- M19-I PRODUCTION DEPLOYMENT = PASS
- M19-I PRODUCTION ACCEPTANCE = PASS
- M19 FINAL RELEASE GATE = PASS

## Gate coverage
Repository/compile/readiness, single Alembic head/current, cumulative sponsor integration, sponsor hardening/tracking, Stream Welcome/scene switching, production configuration/storage preflight, and read-only pre/post database baselines.

Historical `validate_m19b.sh` intentionally pins migration 0027, so M19-I does not execute it against cumulative schema 0031; later cumulative validation plus structural integration checks cover the release state.

## Production acceptance
Verify the exact deployed SHA, migration 0031, health endpoints, sponsor CRUD/artwork/assignment, Sponsor Zone rotation/fallback/fade, sponsor reporting, Welcome upload/enable/remove, Welcome -> Live, public `/stream`, `/overlay`, `/broadcast`, and scoreboard/clock/roster/scoring behavior. Capture and review the post-deploy baseline.

## Billing boundary
M19 does not change billing. Keep `BILLING_LIVE_ENABLED=false` for this gate. Stripe Test Mode E2E can be validated separately after M19 production acceptance.

## Main/tag boundary
Do not merge M19 to `main` or alter production tags merely because local validation passes. Complete production acceptance first and inspect the known `main` / immutable `m18-production` relationship. Never move the existing production tag.
