#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo "=== M19-F Validation ==="
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile app/services/game_sponsor_presentation_service.py scripts/apply_m19f_integrations.py scripts/regression/m19f_sponsor_hardening.py
echo "PASS: Host compile"
sudo docker compose exec app python -m py_compile app/services/game_sponsor_presentation_service.py app/api/game_sponsor_presentation.py
echo "PASS: Container compile"
python3 scripts/regression/m19f_sponsor_hardening.py
ready=0
for attempt in $(seq 1 30); do if curl -fsS http://127.0.0.1:8000/health/ready >/dev/null 2>&1; then echo "PASS: readiness ${attempt}/30";ready=1;break;fi; echo "Readiness check ${attempt}/30...";sleep 2;done
if [ "$ready" -ne 1 ]; then sudo docker compose ps || true;sudo docker compose logs --tail=120 app || true;exit 1;fi
curl -fsS http://127.0.0.1:8000/health/live;echo
curl -fsS http://127.0.0.1:8000/health/ready;echo
sudo docker compose exec app sh -c 'test -d "$SPONSOR_ARTWORK_STORAGE_DIR" && test -w "$SPONSOR_ARTWORK_STORAGE_DIR" && test "$(id -u)" != "0"'
echo "PASS: sponsor artwork storage writable by non-root runtime"
sudo docker compose exec app alembic heads
sudo docker compose exec app alembic current
git diff --check
echo "M19-F VALIDATION: PASS"
