# M18-A — Billing Domain & Entitlement Architecture

## Scope

M18-A establishes the provider-neutral commercial domain foundation only.

It adds:
- Club-level Subscription
- provider-neutral Plan definitions
- named Entitlements and PlanEntitlement mappings
- provider external references
- replay/idempotency-oriented BillingEvent persistence
- a central entitlement resolution service
- a provider-neutral webhook-verification contract
- `CUSTOM_OVERLAY_BRANDING` as a commercial capability

It does **not** add:
- public signup
- hosted checkout
- Stripe or Paddle SDKs
- webhook HTTP endpoints
- commercial provisioning
- billing portal UX
- product-wide entitlement enforcement
- customer logo upload/storage
- organization branding UI
- overlay branding changes
- billing lifecycle/recovery policy

Those remain M18-B through M18-J work.

## Authority boundaries

- PostgreSQL remains authoritative for ScoreStreamLive application subscription state.
- The selected payment provider will later be authoritative only for verified payment truth/events.
- REST remains the durable product mutation boundary.
- Socket.IO remains committed-state notification transport only.
- Billing does not become authoritative for game state.

## Commercial identity

ScoreStreamLive UUIDs remain application primary keys.

Provider-owned customer/subscription/event IDs are external references and never
become ScoreStreamLive resource identity.

## Entitlement resolution

Application code asks whether a Club has a named capability. It does not inspect
Stripe/Paddle product IDs or price IDs.

M18-A defines:
- `CREATE_GAMES`
- `MANAGE_USERS`
- `BROADCAST_OVERLAY`
- `CUSTOM_OVERLAY_BRANDING`

No commercial plan/pricing catalog is seeded yet.

## Existing Club compatibility

M18-A does not automatically grant every paid capability to pre-M18 Clubs.
The entitlement service accepts an explicit `legacy_default` chosen by the caller.

This allows current M17 behavior to remain available during migration without
implicitly granting new paid features such as custom overlay branding.

## Lifecycle

Schema states:
- PENDING
- ACTIVE
- PAST_DUE
- CANCELED
- EXPIRED

M18-A conservatively treats only ACTIVE as granting paid entitlements.
M18-H must explicitly define grace periods, cancellation-period access,
past-due behavior, expiration, recovery, and branding fallback before those
states are used for customer-facing lifecycle enforcement.

## Billing event safety

Billing events use `(provider, external_event_id)` uniqueness as the persistence
idempotency barrier.

The M18-A event record stores audit metadata and an optional payload digest, not
raw sensitive provider payloads.

Actual signature verification and transactional provisioning belong to M18-D.

## Branding relationship

Billing/entitlements determine whether custom branding may be used.

Branding data itself belongs to the Club branding domain and durable object
storage architecture to be implemented in M18-G.

## Validation

M18-A is cumulative. `scripts/validate_m18a.sh` first runs the accepted
standard M17 cumulative validator unchanged, then runs the focused
`Billing Domain & Entitlements` regression domain. This deliberately avoids
changing M17-J's accepted release-gate domain-count assertion during M18-A.
