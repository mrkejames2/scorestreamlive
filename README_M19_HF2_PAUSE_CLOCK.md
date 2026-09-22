# M19 HF2 — Pause/Resume Clock Relocation

Moves the existing authoritative Pause/Resume Clock control from the Match Clock
configuration card into Game Lifecycle, directly after Start First Half.

Desktop order:

    Start First Half | Pause/Resume Clock | End First Half | Start Second Half | End Game

Important:
- Reuses the existing `clock-pause-resume-button` ID.
- Reuses existing `control.js` pause/resume logic and API calls.
- Keeps automatic `Pause Clock` / `Resume Clock` label behavior.
- Keeps authoritative-state, phase, clock-status, in-flight, and version-conflict protections.
- Does NOT add `.lifecycle-button` to Pause/Resume.
- Removes the old visible Pause/Resume control from Match Clock.
- No backend, API, Alembic, model, or database changes.
- Adds a CSS override loaded last for lifecycle-sized desktop/mobile presentation.

Apply from the repository root:

    python3 scripts/apply_m19_hf2_pause_clock.py

Then inspect and validate before commit/push.
