# ScoreStreamLive M11-F Installation

M11-F adds automatic broadcast presentation for lifecycle transitions.

## Replace

```text
templates/overlay/game.html
static/css/overlay.css
static/js/overlay/overlay.js
```

## Add

```text
scripts/validate_m11f.sh
scripts/create_m11f_demo.sh
M11F_HUMAN_ACCEPTANCE.md
M11F_RELEASE_NOTES.md
```

No database migration or backend/domain change is introduced.

## Rebuild

```bash
chmod +x scripts/validate_m11f.sh
chmod +x scripts/create_m11f_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11f.sh
```

## Human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11f_demo.sh
```

The human demo is intended to prove First Half, Halftime, Second Half, Full Time,
and the preserved M11-E Goal banner without requiring any overlay refresh.
