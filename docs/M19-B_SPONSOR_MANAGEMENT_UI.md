# M19-B Sponsor Management UI

M19-B adds a Director-only Sponsor Management page at `/account/sponsors` over the M19-A sponsor domain/API.

## Scope
- Sponsor library listing and empty state.
- Create/edit sponsor name, website, active state, display order, start/end dates.
- Upload, replace, remove, and preview PNG/JPEG/WebP sponsor artwork.
- Permanent sponsor deletion with explicit confirmation.
- Director-only page and API authorization.

## Explicitly out of scope
- Game sponsor assignment.
- Live overlay sponsor placement or rotation.
- Sponsor billing, Stripe, checkout, or payment fields.
- Database migration or sponsor-domain redesign.

## UX behavior
Artwork uses `object-fit: contain` so sponsor logos are never intentionally cropped. Browser `datetime-local` values are converted to ISO timestamps for the API. The UI validates end >= start before submission while the backend remains authoritative. Empty optional website/date values are sent as JSON null so existing values can be cleared.
