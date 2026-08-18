# M11-F Cross-Display Clock Sync Fix

Replace:

```text
static/js/control/clock.js
static/js/control/control.js
```

The overlay file does not change.

Rebuild:

```bash
sudo docker compose down
sudo docker compose up --build -d
```

Validate architecture:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11f_clock_sync.sh
```

Then rerun the existing full M11-F regression:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11f.sh
```

Human acceptance:
compare Control Center vs Overlay at 30s, 60s, 2m, and 5m.
Target: <= 1 second difference at every checkpoint, with no sustained drift.
