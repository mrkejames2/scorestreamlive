#!/usr/bin/env bash
set -euo pipefail
echo '=== M19-H Validation ==='
python3 -m compileall -q app alembic/versions scripts/regression/m19h_stream_intro.py
echo 'PASS: Host compile'
sudo docker compose exec app python -m compileall -q app alembic/versions
echo 'PASS: Container compile'
python3 scripts/regression/m19h_stream_intro.py
ready=0
for i in $(seq 1 30);do if curl -fsS http://127.0.0.1:8000/health/ready >/tmp/m19h-ready.json 2>/dev/null;then echo "PASS: readiness $i/30";ready=1;break;fi;sleep 2;done
if [ "$ready" -ne 1 ];then sudo docker compose ps;sudo docker compose logs --tail=100 app;exit 1;fi
cat /tmp/m19h-ready.json;echo;curl -fsS http://127.0.0.1:8000/health/live;echo
sudo docker compose exec app alembic heads
sudo docker compose exec app alembic current
echo 'M19-H VALIDATION: PASS'
