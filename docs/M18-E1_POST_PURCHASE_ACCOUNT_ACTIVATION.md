# M18-E1 — Post-Purchase Account Activation

M18-E1 closes the customer-journey gap after authoritative Stripe provisioning.

## Authority boundary

`checkout.session.completed` remains the initial payment/provisioning authority. The
browser `/checkout/success` return remains informational only.

M18-D provisioning still creates the Club, ACTIVE Subscription, and inactive DIRECTOR.
M18-E1 additionally creates a hashed, expiring, single-use activation credential in the
same durable provisioning transaction. After that transaction commits, email delivery
is attempted separately. SMTP failure never rolls back or marks a valid payment and
provisioned account as failed.

## Activation flow

1. Verified Stripe event provisions the tenant and inactive DIRECTOR.
2. A cryptographically random activation token is generated.
3. Only SHA-256(token) is stored in PostgreSQL.
4. Provisioning commits.
5. The activation email is attempted.
6. `/activate-account?token=...` validates the credential.
7. Existing password policy and Argon2 hashing are reused.
8. The existing DIRECTOR User becomes `is_active=True`.
9. The activation credential is consumed.
10. A normal authenticated session is created.

## Recovery

`/resend-activation` returns a generic response regardless of account existence.
Only an inactive provisioned DIRECTOR is eligible. A resend revokes/supersedes prior
credentials. Successfully delivered credentials are throttled by
`ACCOUNT_ACTIVATION_RESEND_SECONDS`; a failed email delivery can be retried immediately
with a newly issued credential.

## Deliberately unchanged

The existing `/activate` route and `UserInvitation` lifecycle remain for MANAGER and
OPERATOR invitations. M18-E1 does not reuse that model because the post-purchase
DIRECTOR User already exists.

Billing management, lifecycle synchronization, entitlement enforcement, and branding
remain outside M18-E1.
