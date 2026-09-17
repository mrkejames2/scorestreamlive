# M19-A — Sponsor Domain

Adds a club-owned sponsor library and sponsor artwork storage.

## Scope
- Sponsor CRUD
- Director-only management API
- PNG/JPEG/WebP artwork storage
- Public immutable artwork retrieval
- Tenant-scoped sponsor access
- Optional active date window and default display order

## Explicitly out of scope
- Stripe/payment integration
- Game-to-sponsor assignments
- Overlay rendering/rotation
- Sponsor management UI
- Reporting/analytics

## Integration edits
M19-A integrates the Sponsor model, sponsor artwork configuration, storage initialization,
and sponsor API router into the existing M18 production application structure.
