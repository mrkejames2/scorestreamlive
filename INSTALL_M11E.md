# ScoreStreamLive M11-E Installation

M11-E adds live goal presentation to the M11-D broadcast overlay.

## Replace

```text
templates/overlay/game.html
static/css/overlay.css
static/js/overlay/overlay.js
```

## Add

```text
scripts/validate_m11e.sh
scripts/create_m11e_demo.sh
M11E_HUMAN_ACCEPTANCE.md
M11E_RELEASE_NOTES.md
```

No database migration or backend/domain change is introduced.

## Rebuild

```bash
chmod +x scripts/validate_m11e.sh
chmod +x scripts/create_m11e_demo.sh

sudo docker compose down
sudo docker compose up --build -d
sudo docker compose ps
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11e.sh
```

## Human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11e_demo.sh
```

Start First Half in the Control Center and record a goal with a selected scorer.
The broadcast overlay should display a goal banner automatically and remove it after about five seconds.
