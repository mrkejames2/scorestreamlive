# M18-D — Verified Billing Events & Initial Tenant Provisioning

M18-D makes a signature-verified Stripe `checkout.session.completed` event the only initial payment authority. Browser success/cancel returns remain UX only.

Flow: raw webhook body + `Stripe-Signature` -> Stripe verification -> replay-safe `BillingEvent` -> Stripe Checkout Session re-read -> correlation/price checks -> one DB transaction creating Club, inactive DIRECTOR User, ACTIVE Subscription, customer/subscription external references, and completion of SignupIntent/CheckoutAttempt/BillingEvent.

Environment adds `STRIPE_WEBHOOK_SECRET=whsec_...`. Never commit Stripe secrets.

The initial User is deliberately `is_active=False` with an unknown random Argon2 hash. M18-D does not invent a customer password; activation/password setup stays separate.

Recovery uses `scripts/reprocess_billing_event.py EVENT_UUID`, re-reading Stripe by persisted checkout-session ID instead of storing raw webhook payloads.
