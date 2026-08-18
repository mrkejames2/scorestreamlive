# M12-D5 — Branded Control Center

## Replace

```text
templates/control/game.html
```

## Add

```text
static/js/control/control-branding.js
static/css/control-d5.css
scripts/validate_m12d5.sh
```

No backend, database, Alembic, clock, lifecycle, scoring, or Socket.IO changes are required.

D5 is intentionally layered beside the accepted Control Center logic. The existing
`static/js/control/control.js` remains unchanged.

## Rebuild

```bash
cd ~/projects/scorestreamlive
chmod +x scripts/validate_m12d5.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m12d5.sh
```

D5 does not modify the broadcast Overlay. Overlay branding is D6.
