#!/usr/bin/env bash
set -euo pipefail

echo "=== M19-A Sponsor Domain Validation ==="


echo
echo "=== Host compile ==="
python3 -m compileall -q app
echo "PASS: Host compile"

echo
echo "=== Container compile ==="
sudo docker compose exec app python3 -m compileall -q app
echo "PASS: Container compile"

echo
echo "=== Sponsor domain smoke ==="
sudo docker compose exec -T app python3 - <<'PY'
from app.models.sponsor import Sponsor
from app.schemas.sponsor import SponsorCreate
from app.services.sponsor_artwork_storage import validate_uploaded_artwork

assert Sponsor.__tablename__ == "sponsors"

SponsorCreate(name="Example Sponsor")

assert validate_uploaded_artwork(
    data=b"\x89PNG\r\n\x1a\nrest",
    declared_content_type="image/png",
) == "png"

print("PASS: M19-A sponsor domain")
print("PASS: Sponsor schema")
print("PASS: Sponsor artwork validation")
PY

echo
echo "=== Alembic head ==="
sudo docker compose exec app alembic heads

echo
echo "=== Database current ==="
sudo docker compose exec app alembic current

echo
echo "=== Application health ==="
curl -fsS http://127.0.0.1:8000/health/live
echo
curl -fsS http://127.0.0.1:8000/health/ready
echo

echo
echo "=== Git diff check ==="
git diff --check
echo "PASS: git diff --check"

echo
echo "M19-A VALIDATION: PASS"
