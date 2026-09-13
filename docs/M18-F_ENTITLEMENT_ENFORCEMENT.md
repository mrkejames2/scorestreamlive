# M18-F — Entitlement Enforcement

M18-F makes the provider-neutral entitlement model authoritative at durable product boundaries.

## Policy
Authentication, existing role/assignment/tenant authorization, and commercial entitlement are separate layers. Entitlements supplement authorization; they never replace it.

Existing entitlements:
- `CREATE_GAMES`
- `MANAGE_USERS`
- `BROADCAST_OVERLAY`
- `CUSTOM_OVERLAY_BRANDING`

Explicit pre-commercial Club compatibility:
- `CREATE_GAMES`: allowed
- `MANAGE_USERS`: allowed
- `BROADCAST_OVERLAY`: allowed
- `CUSTOM_OVERLAY_BRANDING`: denied

Commercial Clubs are resolved strictly from PostgreSQL Subscription → PlanEntitlement state. Only `ACTIVE` grants paid entitlements until M18-H defines lifecycle/grace-period policy.

## Enforcement
- `POST /api/games` requires `CREATE_GAMES`.
- Club invitation/member/assignment mutations require `MANAGE_USERS`.
- Control, overlay, overlay-state, broadcast page, and broadcast-message mutation require `BROADCAST_OVERLAY`.
- Authenticated clients can read `/api/account/entitlements`.
- Billing, activation, recovery, and account security remain accessible.
- M18-F establishes the custom-branding entitlement policy; M18-G implements branding itself.

Runtime entitlement checks never call Stripe.
