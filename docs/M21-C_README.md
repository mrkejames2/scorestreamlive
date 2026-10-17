# M21-C — Futsal Countdown Clock (local integration candidate)

## Scope
Dedicated Futsal countdown controller, 1–60-minute halves, manual stop/resume, running-clock or stop-clock policy, half transition, persisted clock via existing GameClock, optimistic version checks, club-scoped API, no per-tick writes.

The running-clock policy is descriptive in this milestone: both modes use manual pause/resume. Automatic referee/stoppage integration is not implemented. The second-half button resets the clock and advances the half; it does not start automatically.

## Install
From repository root:

    unzip -o ScoreStreamLive_M21-C.zip
    python3 scripts/apply_m21c.py
    git diff --check
    sudo docker compose up -d --build
    sudo docker compose exec app alembic heads
    sudo docker compose exec app alembic upgrade head
    sudo docker compose exec app alembic current

Expected head: `20261016_0041`.

## Test
Open `/futsal/games/<game-id>/clock` for a futsal game. Initialize, start, pause, resume, reset, switch to second half, refresh while running. Verify soccer clock still works. No GitHub push.

## Important
This milestone does not wire the clock into the existing game detail/control-center UI; direct controller URL is used. M21-D integrates overlay. Do not mark PASS until local browser validation.
