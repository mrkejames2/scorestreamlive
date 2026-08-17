# ScoreStreamLive M10-D Installation

M10-D adds operator scoring controls to the existing M10-C Control Center. It does not add or change backend scoring architecture.

## Files to replace/add

Copy these files from the package into the repository root:

- `templates/control/game.html` — replace
- `static/css/control.css` — replace
- `static/js/control/api.js` — replace
- `static/js/control/control.js` — replace
- `scripts/validate_m10d.sh` — add
- `scripts/validate_m10a.sh` — keep/replace with the known-good capability regression validator
- `scripts/validate_m10b.sh` — keep/replace with the known-good capability regression validator
- `scripts/validate_m10c.sh` — keep/replace with the known-good capability regression validator

No Python/backend, model, schema, migration, or Socket.IO server files change in M10-D.

## Safe install

From the repository root:

```bash
cp -v <PACKAGE>/templates/control/game.html templates/control/game.html
cp -v <PACKAGE>/static/css/control.css static/css/control.css
cp -v <PACKAGE>/static/js/control/api.js static/js/control/api.js
cp -v <PACKAGE>/static/js/control/control.js static/js/control/control.js
cp -v <PACKAGE>/scripts/validate_m10*.sh scripts/
chmod +x scripts/validate_m10a.sh scripts/validate_m10b.sh scripts/validate_m10c.sh scripts/validate_m10d.sh
```

Because templates/static files are copied into the Docker image by the current Dockerfile, rebuild:

```bash
sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://YOUR_VM_IP:8000" ./scripts/validate_m10d.sh
```

M10-D runs its scoring-control checks first, then invokes M10-C. M10-C continues the established M10-B -> M10-A -> M9 regression chain.

## Visual test

Open an existing/demo game:

```text
http://YOUR_VM_IP:8000/control/games/<GAME_ID>
```

Expected M10-D behavior:

1. Scoring buttons are disabled in Pregame.
2. Start First Half using the M10-C lifecycle control.
3. Home/Away goal buttons become available while live connection is healthy.
4. Choose a roster player or leave `Team Goal / Unknown Scorer` selected.
5. Record a goal.
6. Score and scoring history update from existing committed Socket.IO events.
7. End First Half: scoring buttons disable during Halftime.
8. Start Second Half: scoring buttons enable again.
9. End Game: scoring buttons disable at Full Time.

M10-D intentionally does not add goal deletion/undo, cards, substitutions, manual score editing, or overlay work.
