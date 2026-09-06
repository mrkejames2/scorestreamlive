# M18-B Public Signup & Onboarding
Public marketing CTA → `/signup` → provider-neutral `SignupIntent` → `READY_FOR_CHECKOUT`.

M18-B creates no User, Club, Subscription, payment, password, or paid entitlement. Verified
billing-event provisioning remains M18-D; hosted checkout remains M18-C.

Active signup for the same normalized email is resumed. Expired intents are lazily marked
EXPIRED. Existing provisioned users receive generic public-safe rejection. Signup state is
durable REST state and introduces no Socket.IO or new infrastructure.
