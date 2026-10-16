# M21-B — Sport-aware teams and games

This package is intentionally additive to M21-A. Existing soccer records migrate to sport='soccer'.

## Install (DevOps1 only)

From repository root:

    unzip -o ScoreStreamLive_M21-B.zip
    python3 scripts/apply_m21b.py
    git diff --check
    python3 -m compileall -q app
    sudo docker compose up --build -d
    sudo docker compose exec app alembic heads
    sudo docker compose exec app alembic current
    sudo docker compose exec app alembic upgrade head

Do not run database upgrade unless current is 20261016_0039 and heads is 20261016_0040.

## Smoke test

- Log in; open /futsal/games
- Create two futsal teams and a futsal game
- Verify /api/teams?sport=futsal and /api/games?sport=futsal only show futsal records
- Verify existing /games soccer dashboard still loads, and soccer teams and games are unchanged
- Verify a futsal game cannot reference a soccer team or a team from another club
- Do not push or deploy until M21 release

## Known scope limitations

This is a preliminary integration package. Futsal game detail currently reuses the existing soccer-style game detail. Futsal roster editing and sport-specific navigation on all screens remain to be refined. M21-C adds the countdown clock.
