# M18-I — Production Deployment & Billing Safety

## Objective
Deploy the cumulative M18 application to the existing Render environment without replacing the production PostgreSQL database, existing users, clubs, teams, games, history, or branding, while Stripe remains in TEST mode and real payments remain disabled.

## Hard invariants
- Existing Render PostgreSQL remains authoritative and is upgraded in place.
- Existing production users/data are never reset, reseeded, or replaced.
- `M15_BOOTSTRAP_ENABLED=false` remains required for production.
- Alembic continues to run through the existing Render rebuild/startup model.
- M18-I introduces no database migration.
- `BILLING_LIVE_ENABLED=false` is the M18-I production requirement.
- A Stripe `sk_live_` key is rejected while live billing is disabled.
- `PUBLIC_BASE_URL` must be HTTPS in production.
- Browser success/cancel routes remain non-authoritative.
- Stripe live enablement is deferred to M18-HOTFIX1.

## Render target configuration
Set production application/security variables as already required, plus:
- `BILLING_PROVIDER=stripe`
- `BILLING_LIVE_ENABLED=false`
- `PUBLIC_CHECKOUT_ENABLED=true` only during controlled M18-J test validation; otherwise false until intentionally opened.
- `STRIPE_SECRET_KEY=sk_test_...`
- `STRIPE_WEBHOOK_SECRET=<test endpoint signing secret>`
- `PUBLIC_BASE_URL=https://<your-render-host>`

Never paste live Stripe credentials during M18-I/M18-J.

## Existing-account compatibility
The accepted entitlement service already grants legacy defaults when a Club has no Subscription: CREATE_GAMES, MANAGE_USERS, and BROADCAST_OVERLAY remain available; CUSTOM_OVERLAY_BRANDING is not granted by legacy default. Do not manufacture a Stripe subscription merely to preserve an existing pre-billing Club. Validate the established production account after deployment.

## Pre-deployment checkpoint
Before deployment, record:
1. current Alembic revision;
2. existing production user is present;
3. counts for users, clubs, teams, games;
4. important existing game/club identifiers needed for spot checks;
5. Render database backup/recovery option is understood.

Do not log passwords, hashes, Stripe secrets, session tokens, or private customer data.

## Deployment
1. Keep the existing Render database connection.
2. Set the billing safety variables above.
3. Deploy the cumulative M18 branch.
4. Allow the existing entrypoint to run Alembic.
5. Wait for `/health/live` and `/health/ready`.
6. Confirm Alembic is at the expected single head.
7. Confirm the established account can log in.
8. Confirm existing teams/games/history remain present.
9. Open an existing game and overlay.
10. Confirm Create Game remains available for the established legacy account.

## Stripe TEST validation
For M18-J, configure a Stripe TEST webhook to the deployed `/api/billing/webhooks/stripe` endpoint and use test Price/customer/payment objects only. `BILLING_LIVE_ENABLED` remains false.

## Rollback
If deployment fails, stop further billing validation. Do not reset/reseed the database. Roll application code back to the previously accepted Render release and use the database recovery mechanism only if a migration itself caused a verified data/schema problem.

## Deferred live launch
M18-HOTFIX1 will intentionally configure live Product/Price objects, live webhook signing secret, live Stripe keys, controlled real-money smoke testing, and the explicit live-billing gate. M18-I does none of those actions.
