# M21-F revision 2 — UI and countdown scoring timestamps

Requires M21-F installed first. Extract at repository root, then `python3 scripts/apply_m21f_r2.py`, `git diff --check`, `sudo docker compose up -d --build`.

- Soccer-style navigation, typography, light content area, and responsive Futsal controls (phone/tablet/desktop).
- Goals show remaining countdown time from authoritative elapsed seconds and configured period length.
- Half inferred using persisted FutsalClockConfig.updated_at half-transition timestamp; **this is not a per-goal persisted half field**. Historical goals or subsequent clock configuration changes may make the inferred half unreliable. A dedicated per-goal period migration is required before production sign-off.
- Goal deletion and scorer correction still use existing authenticated scoring APIs.
- No Soccer templates, API, or CSS are modified.
- Test on phone 375px, tablet, and desktop; verify both halves, reset confirmation, scorer change, removal, and overlay.
