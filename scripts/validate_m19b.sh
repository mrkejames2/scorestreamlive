#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
echo "=== M19-B Sponsor Management UI Validation ==="
echo "=== Host compile ==="; python3 -m compileall -q app; echo "PASS: Host compile"
echo "=== Container compile ==="; sudo docker compose exec -T app python3 -m compileall -q app; echo "PASS: Container compile"
echo "=== Route/static integration ==="
grep -q 'sponsors_web_router' app/main.py
grep -q 'href="/account/sponsors"' templates/account/index.html
grep -q '/api/account/sponsors' static/js/sponsors.js
grep -q 'Game assignment and live overlay display arrive in later M19 milestones' templates/account/sponsors.html
if grep -Eqi 'stripe|checkout|payment' templates/account/sponsors.html static/js/sponsors.js app/web/sponsors.py; then echo 'FAIL: billing/payment coupling found in M19-B runtime files'; exit 1; fi
echo "PASS: M19-B integration"
echo "=== HTTP health ==="; curl -fsS "$BASE_URL/health/live"; echo; curl -fsS "$BASE_URL/health/ready"; echo
echo "=== Anonymous page protection ==="; code=$(curl -sS -o /tmp/m19b-anon.out -w '%{http_code}' "$BASE_URL/account/sponsors"); test "$code" = "401"; echo "PASS: anonymous /account/sponsors -> 401"
echo "=== Alembic unchanged from M19-A ==="

sudo docker compose exec -T app alembic heads > /tmp/m19b-alembic-heads.txt
cat /tmp/m19b-alembic-heads.txt
grep -q '20260917_0027' /tmp/m19b-alembic-heads.txt

sudo docker compose exec -T app alembic current > /tmp/m19b-alembic-current.txt 2>&1
cat /tmp/m19b-alembic-current.txt
grep -q '20260917_0027' /tmp/m19b-alembic-current.txt

echo "PASS: no M19-B migration"

echo "=== Git diff check ==="; git diff --check; echo "PASS: git diff --check"
echo "M19-B VALIDATION: PASS"
