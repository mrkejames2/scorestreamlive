# M19-F — Sponsor Presentation & Production Hardening

M19-F hardens M19-A through M19-E without adding billing or impression tracking.

- Rotation aligns sponsor position and next transition to persisted `updated_at`.
- Anonymous overlay-state reads do not create presentation rows.
- Authenticated reads durably reconcile an ineligible current sponsor.
- Artwork is preloaded; failed URLs are suppressed for the overlay session.
- Render generations prevent stale asynchronous work from overwriting newer state.
- Docker pre-creates `static/uploads/sponsor-artwork` as writable app storage.
- No migration; Alembic remains `20260918_0029`.

## Production storage contract
The Compose named volume solves local persistence only. Production must mount persistent writable storage and set `SPONSOR_ARTWORK_STORAGE_DIR` to that path before cumulative M19 production release.

## Human acceptance
1. Fresh artwork storage.
2. Boundary-aligned rotation across two overlays.
3. Refresh/reconnect recovery.
4. Broken artwork recovery and SSL fallback.
5. Control/rotation collision protection.
6. Durable eligibility recovery.
7. Long-running/container-restart persistence.
