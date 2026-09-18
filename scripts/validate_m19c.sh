#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
echo "=== M19-C Game Sponsor Assignment Validation ==="
echo "=== Host compile ==="; PYTHONDONTWRITEBYTECODE=1 python3 -m compileall -q app; echo "PASS: Host compile"
echo "=== Container compile ==="; sudo docker compose exec app python3 -m compileall -q app; echo "PASS: Container compile"
echo "=== Integration ==="; grep -q game_sponsors_router app/main.py; grep -q GameSponsor app/models/__init__.py; grep -q game-sponsors-panel templates/games/detail.html; grep -q '/sponsors' static/js/games/detail.js; echo "PASS: M19-C integration"
echo "=== HTTP health ==="; curl -fsS "$BASE_URL/health/live"; echo; curl -fsS "$BASE_URL/health/ready"; echo
echo "=== OpenAPI ==="; curl -fsS "$BASE_URL/openapi.json" >/tmp/m19c-openapi.json; grep -q '/api/games/{game_id}/sponsors' /tmp/m19c-openapi.json; echo "PASS: API exposed"
echo "=== Migration chain ==="; grep -q 'revision="20260917_0028"' alembic/versions/20260917_0028_add_game_sponsor_assignments.py; grep -q 'down_revision="20260917_0027"' alembic/versions/20260917_0028_add_game_sponsor_assignments.py; echo "PASS: 0028 -> 0027"
echo "=== Git diff check ==="; git diff --check; echo "PASS: git diff --check"
echo "M19-C VALIDATION: PASS"
