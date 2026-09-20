#!/usr/bin/env bash
set -euo pipefail
echo "=== M19-G Validation ==="
python3 -m compileall -q app scripts; echo "PASS: Host compile"
sudo docker compose exec app python -m compileall -q app; echo "PASS: Container compile"
python3 scripts/regression/m19g_sponsor_tracking.py
for i in $(seq 1 30);do if curl -fsS http://127.0.0.1:8000/health/ready >/dev/null;then echo "PASS: readiness $i/30";break;fi;if [ "$i" = 30 ];then sudo docker compose ps;sudo docker compose logs --tail=120 app;exit 1;fi;sleep 2;done
curl -fsS http://127.0.0.1:8000/health/live;echo
curl -fsS http://127.0.0.1:8000/health/ready;echo
sudo docker compose exec app alembic heads
sudo docker compose exec app alembic current
git diff --check
echo "M19-G VALIDATION: PASS"
