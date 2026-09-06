# M18-C Hosted Checkout

M18-C connects a `READY_FOR_CHECKOUT` SignupIntent to provider-hosted checkout.

## Authority boundary

- PostgreSQL remains authoritative application state.
- Stripe is the selected hosted-checkout provider implementation.
- Browser success/cancel redirects are never payment truth.
- M18-C creates no User, Club, Subscription, membership, or entitlement activation.
- Verified webhooks and provisioning remain M18-D.

## Checkout persistence and recovery

`CheckoutAttempt` records what ScoreStreamLive attempted.
`BillingExternalReference` maps provider checkout-session IDs to the SignupIntent.
`BillingPriceReference` maps an internal Plan to an external provider Price without putting Stripe IDs on Plan.

Hardening rules:
- Exactly one active provider Price mapping exists per Plan/provider.
- Exactly one active (`CREATING` or `OPEN`) CheckoutAttempt exists per SignupIntent/Plan/provider.
- Provider idempotency keys are unique per logical CheckoutAttempt.
- A usable OPEN attempt is reused.
- An expired OPEN attempt is marked EXPIRED and replaced with a new attempt/new provider key.
- An interrupted CREATING attempt is recovered using the same provider key after a short retry window.
- Checkout destinations must be HTTPS.
- Provider external-reference ownership collisions fail closed.

## Configuration

Set:
- `BILLING_PROVIDER=stripe`
- `STRIPE_SECRET_KEY=<Stripe test/live secret>`
- `PUBLIC_BASE_URL=<externally reachable ScoreStreamLive base URL>`

After migration, configure a Plan -> Stripe Price mapping with:

`python scripts/configure_m18c_stripe_price.py --plan-code <CODE> --plan-name "<NAME>" --stripe-price-id <price_...> --amount-minor <cents> --currency usd --interval month`

No plan or price is silently seeded by M18-C.
