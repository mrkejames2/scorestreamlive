# M21-F — Final integration validation candidate

Baseline: `2485872` on `feature/m21-a-multisport-foundation`.

## Scope
- Redirect authenticated Futsal operators from `/control/games/<uuid>` to `/futsal/games/<uuid>/control`; Soccer is unchanged.
- Overlay period label follows Futsal period endpoint.
- Futsal Control Center gains native scoring-event corrections and goal removal.
- No migrations; no automatic Git commits, pushes or Render deployments.

## Install
From repository root after unzipping:
```sh
python3 scripts/apply_m21f.py
git diff --check
sudo docker compose up -d --build
```

## Validation
1. Futsal Control Center: add home/away goals, change scorer, remove goal, verify score.
2. Futsal first/second half: verify overlay shows corresponding half.
3. `/control/games/<futsal-id>` redirects to Futsal controls; Soccer URL stays Soccer.
4. Reload during active clock and after pause; verify authoritative state.
5. Confirm Soccer overlay and control still function.

## Known limitation
The Futsal period endpoint currently provides only period 1/2, not a complete halftime/full-time lifecycle. Do not claim final match-state parity until a separate authoritative Futsal match-state model is implemented and validated. This ZIP is a validation candidate, not an automatic PASS.
