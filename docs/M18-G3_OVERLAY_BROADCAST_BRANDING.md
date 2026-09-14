# M18-G3 — Overlay / Broadcast Branding Integration

G3 projects one authoritative effective Club-branding object into the live overlay-state and public game-summary payloads.

Rules:
- entitled + configured => Club branding
- not entitled => default ScoreStreamLive branding
- entitled but not configured => default ScoreStreamLive branding
- missing logo => text fallback
- Team logos/colors remain unchanged
- disabling entitlement never deletes stored Club branding
