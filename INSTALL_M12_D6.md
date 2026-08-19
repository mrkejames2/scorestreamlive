# M12-D6 — Branded Broadcast Overlay + M12-D Final Gate

## Replace

```text
templates/overlay/game.html
static/js/overlay/overlay.js
```

## Add

```text
static/css/overlay-d6.css
scripts/validate_m12d6.sh
```

No backend, database, Alembic, scoring, lifecycle, clock, or Socket.IO changes are required.

D6 uses the Team objects already loaded by the authoritative overlay bootstrap. It adds no extra REST reads.

## Rebuild

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12d6.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12d6.sh
```

The validator checks broadcast branding, runs the M12-D5 cumulative regression, and runs the M11-G broadcast release regression.
