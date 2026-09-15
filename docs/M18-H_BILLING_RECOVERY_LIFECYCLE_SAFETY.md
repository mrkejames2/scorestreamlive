# M18-H — Billing Recovery & Lifecycle Safety

## Objective

Make subscription lifecycle transitions deterministic, recoverable, tenant-safe,
entitlement-safe, data-preserving, auditable, and resilient while preserving the
accepted M18-A through M18-G architecture.

## Domain policy

- PostgreSQL remains authoritative for application behavior.
- Verified/retrieved provider state is authoritative for correcting local billing state.
- Browser redirects never activate or mutate billing state.
- `ACTIVE` grants paid entitlements, including `cancel_at_period_end=true` before termination.
- `PAST_DUE` receives a bounded grace period (`BILLING_PAST_DUE_GRACE_DAYS`, default 7)
  measured from `current_period_end`.
- `CANCELED` and `EXPIRED` do not grant paid entitlements.
- Entitlement loss never deletes Club, users, teams, players, games, history,
  `ClubBranding`, or branding assets.
- `CUSTOM_OVERLAY_BRANDING` therefore falls back through the existing effective
  branding projection and automatically returns when entitlement recovers.

## Durable lifecycle replay

M18-H HARDENING1 adds `billing_events.subscription_external_id`.

This is intentionally separate from `object_external_id`:

- `customer.subscription.*`: object ID is normally the subscription ID.
- `invoice.*`: object ID is the invoice ID, while the related subscription ID is
  persisted in `subscription_external_id`.

This preserves the existing durable-inbox design without storing full Stripe
payloads and allows a FAILED invoice lifecycle event to be replayed deterministically
by retrieving the current provider subscription.

Rows created before M18-H can be enriched on provider redelivery. Existing
`customer.subscription.*` rows are also replayable from `object_external_id`.
A legacy invoice row that never captured subscription identity cannot be inferred
safely and requires one provider redelivery.

## Ordering

The Subscription stores:

- `last_provider_event_created_at`
- `last_provider_event_id`

An event older than the applied watermark cannot regress state. A duplicate event
with the same ID/timestamp is idempotent. Distinct Stripe events that share the same
second-resolution timestamp are allowed to reconcile because the service retrieves
the provider's current subscription snapshot rather than treating the event name as
a state command.

## Lifecycle synchronization

Supported lifecycle notifications:

- `customer.subscription.updated`
- `customer.subscription.deleted`
- `invoice.payment_failed`
- `invoice.paid`
- `invoice.payment_succeeded`

The notification identifies the subscription; ScoreStreamLive retrieves current
provider truth and applies a normalized snapshot through the provider-neutral
lifecycle service.

## Status mapping

- provider `active` -> `ACTIVE`
- provider `past_due` / `unpaid` -> `PAST_DUE`
- provider `incomplete` / `incomplete_expired` / `trialing` / `paused` -> `PENDING`
- provider `canceled` after scheduled period-end cancellation -> `EXPIRED`
- provider `canceled` without scheduled period-end cancellation -> `CANCELED`

No new Subscription statuses are introduced.

## Recovery and operator reconciliation

`scripts/reprocess_billing_event.py` continues to use the durable inbox.
HARDENING1 makes new invoice lifecycle events replayable because their related
subscription identity is now persisted.

`scripts/reconcile_subscription.py` remains the bounded operator path for directly
reconciling a known provider subscription ID against current provider truth.

## Human acceptance

1. ACTIVE paid capabilities work.
2. Custom Club branding displays while entitled.
3. Payment failure reaches PAST_DUE.
4. Grace behavior matches configuration.
5. Entitlement loss falls back to ScoreStreamLive branding without deleting stored branding.
6. Recovery returns ACTIVE and restores the existing Club branding automatically.
7. `cancel_at_period_end` remains ACTIVE through the paid period.
8. Terminal cancellation/expiration removes effective paid access without deleting customer data.
9. Duplicate delivery does not duplicate mutation.
10. Older delivery cannot regress newer state.
11. FAILED invoice lifecycle processing can be replayed from the durable inbox.
12. Reconciliation restores provider/local agreement.
13. Tenant ownership cannot cross subscription references.
14. FAST and release validation remain green.
15. Existing compact scoreboard/overlay visual behavior is unchanged.
