# M11-C Clock Precision Cleanup

This replaces the 30-second full-state periodic re-anchor with a 5-second clock-only authoritative re-anchor.

Replace:

```text
static/js/overlay/overlay.js
scripts/validate_m11c.sh
```

No backend, database, template, route, or Control Center changes.

Rebuild:

```bash
sudo docker compose down
sudo docker compose up --build -d
```

Validate:

```bash
sudo BASE_URL="http://192.168.12.133:8000" \
  ./scripts/validate_m11c.sh
```

Then rerun the existing M11-C human demo and compare the overlay to the Control Center for at least 90 seconds. Target: normally within ±1 second and no manual refresh.
