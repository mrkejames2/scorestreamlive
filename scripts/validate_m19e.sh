#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== M19-E Live Sponsor Controls Validation ==="
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile app/models/game_sponsor_presentation.py app/schemas/game_sponsor_presentation.py app/services/game_sponsor_presentation_service.py app/api/game_sponsor_presentation.py
echo "PASS: Host compile"
sudo docker compose exec app python -m py_compile app/models/game_sponsor_presentation.py app/schemas/game_sponsor_presentation.py app/services/game_sponsor_presentation_service.py app/api/game_sponsor_presentation.py
echo "PASS: Container compile"
python3 - <<'P'
from pathlib import Path
m=Path('app/main.py').read_text();c=Path('app/api/control.py').read_text();h=Path('templates/control/game.html').read_text();o=Path('static/js/overlay/overlay.js').read_text()
assert 'game_sponsor_presentation_router' in m
assert '"sponsor_presentation": await serialize_presentation' in c
assert 'id="m19e-sponsor-controls"' in h
assert 'sponsor:presentation_updated' in o
print('PASS: M19-E integration')
P
curl -fsS http://127.0.0.1:8000/health/live; echo
curl -fsS http://127.0.0.1:8000/health/ready; echo
echo '=== Alembic (expected 20260918_0029 head/current) ==='
sudo docker compose exec app alembic heads
sudo docker compose exec app alembic current
git diff --check
echo 'M19-E VALIDATION: PASS'
