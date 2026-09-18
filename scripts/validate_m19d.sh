#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== M19-D Live Overlay Sponsor Placement Validation ==="
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile app/services/effective_game_sponsor_service.py app/api/control.py
echo "PASS: Host compile"
sudo docker compose exec app python -m py_compile app/services/effective_game_sponsor_service.py app/api/control.py
echo "PASS: Container compile"
python3 - <<'PY'
from pathlib import Path
c=Path('app/api/control.py').read_text();h=Path('templates/overlay/game.html').read_text();j=Path('static/js/overlay/overlay.js').read_text();s=Path('app/services/effective_game_sponsor_service.py').read_text()
assert '"sponsors": await get_effective_game_sponsors' in c
assert 'id="sponsor-zone"' in h and 'overlay-sponsors-m19d.css?v=m19d-1' in h and 'overlay.js?v=m19d-1' in h
assert 'DEFAULT_SPONSOR_ROTATION_MS = 10000' in j and 'syncSponsorRotation()' in j and 'sponsorRotationTimer' in j
assert 'Sponsor.is_active.is_(True)' in s and 'Sponsor.artwork_url.is_not(None)' in s and 'Sponsor.starts_at' in s and 'Sponsor.ends_at' in s
print('PASS: M19-D integration')
PY
curl -fsS http://127.0.0.1:8000/health/live; echo
curl -fsS http://127.0.0.1:8000/health/ready; echo
echo '=== Alembic (expected unchanged: 20260917_0028 head/current) ==='
sudo docker compose exec app alembic heads
sudo docker compose exec app alembic current
git diff --check
echo 'M19-D VALIDATION: PASS'
