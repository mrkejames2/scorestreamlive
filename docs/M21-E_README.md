# M21-E — Futsal Rules & Operator Controls (validation candidate)

Built against pushed branch `feature/m21-a-multisport-foundation` after M21-D.

## Features
- Authenticated, game-scoped Futsal operator page `/futsal/games/<uuid>/control`.
- Clock start/pause/resume/reset, second-half advance through existing M21-C versioned clock endpoints.
- Home/away goals via existing scoring-event service (idempotency request ID).
- Public entitlement-gated Futsal period metadata endpoint `/api/public/futsal/games/<uuid>/period`.
- No changes to Soccer overlay, Soccer control UI, or existing clock service.

## Important limitations for validation
- This is a **validation candidate**, not a finished rules engine. Full-time/lifecycle transitions still use the existing Control Center. Foul accumulation, timeouts, cards, substitutions, automatic stoppages, and overtime are not implemented.
- M21-D overlay still derives its phase label from the generic lifecycle. The new period metadata endpoint is available for integration in M21-F; it is not wired into M21-D in this candidate.
- Existing generic scoring API may enforce lifecycle phase requirements. If goal buttons fail before the lifecycle is started, use the main Control Center to start the match.
- The public overlay-state endpoint requires the club's broadcast entitlement, so the operator screen needs that entitlement too.

## Install
From the repository root with ZIP present:

```bash
unzip -o ScoreStreamLive_M21-E.zip
python3 scripts/apply_m21e.py
git diff --check
sudo docker compose up -d --build
sudo docker compose ps
```

No migration. Open `http://127.0.0.1:8000/futsal/games/9ee3d5d5-70d3-42a7-92af-3793c71bd263/control` while logged in.

Validate score updates, clock controls, second-half advance, authorization and Soccer regression before declaring PASS. No automatic Git push or production deploy.
