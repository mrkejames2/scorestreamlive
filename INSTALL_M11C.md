# ScoreStreamLive M11-C Installation

M11-C hardens the live broadcast clock for unattended OBS/Streamlabs use.

## Replace

```text
static/js/overlay/overlay.js
```

## Add

```text
scripts/validate_m11c.sh
scripts/create_m11c_demo.sh
M11C_HUMAN_ACCEPTANCE.md
M11C_RELEASE_NOTES.md
```

No backend code, database migration, route, template, or Control Center change is required.

## Rebuild

Because static assets are copied into the application image:

```bash
chmod +x scripts/validate_m11c.sh
chmod +x scripts/create_m11c_demo.sh

sudo docker compose down
sudo docker compose up --build -d
```

## Validate

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11c.sh
```

## Human demo

```bash
BASE_URL="http://192.168.12.133:8000" \
  ./scripts/create_m11c_demo.sh
```
