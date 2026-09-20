#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
EXPECTED_BRANCH="${EXPECTED_BRANCH:-milestone/m19-i-final-production-release-gate}"
EXPECTED_HEAD="${EXPECTED_ALEMBIC_HEAD:-20260920_0031}"
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
echo '=== M19-I Local Cumulative Release Validation ==='
branch="$(git branch --show-current)"; [[ "$branch" == "$EXPECTED_BRANCH" ]] || { echo "FAIL: expected $EXPECTED_BRANCH, found $branch" >&2; exit 1; }; echo "PASS: branch $branch"
required=(scripts/validate_m19a.sh scripts/validate_m19f.sh scripts/validate_m19g.sh scripts/validate_m19h.sh app/models/sponsor.py app/models/game_sponsor.py app/models/game_sponsor_presentation.py app/models/sponsor_impression.py app/models/game_broadcast_presentation.py app/web/stream.py)
for f in "${required[@]}"; do test -f "$f" || { echo "FAIL: missing $f" >&2; exit 1; }; done
echo 'PASS: required cumulative M19 artifacts present'
PYTHONDONTWRITEBYTECODE=1 python3 -m compileall -q app alembic/versions scripts/regression; echo 'PASS: host compile'
sudo docker compose exec app python3 -m compileall -q app alembic/versions; echo 'PASS: container compile'
ready=0; for attempt in $(seq 1 30); do if curl -fsS "${BASE_URL}/health/ready" >/tmp/m19i-ready.json 2>/dev/null; then echo "PASS: readiness ${attempt}/30"; ready=1; break; fi; sleep 2; done
if [[ "$ready" -ne 1 ]]; then echo 'FAIL: readiness timeout' >&2; sudo docker compose ps || true; sudo docker compose logs --tail=120 app || true; exit 1; fi
cat /tmp/m19i-ready.json; echo; curl -fsS "${BASE_URL}/health/live"; echo
echo "--- alembic heads ---"
timeout 15s sudo docker compose exec app sh -c "alembic heads > /tmp/m19i-alembic-heads.txt && cat /tmp/m19i-alembic-heads.txt && grep -q '$EXPECTED_HEAD (head)' /tmp/m19i-alembic-heads.txt" || {
    rc=$?
    echo "FAIL: Alembic heads check failed or timed out (exit=$rc)" >&2
    exit "$rc"
}
echo "PASS: expected Alembic head $EXPECTED_HEAD"
echo "--- alembic current ---"
timeout 15s sudo docker compose exec app sh -c "alembic current > /tmp/m19i-alembic-current.txt 2>&1 && cat /tmp/m19i-alembic-current.txt && grep -q '$EXPECTED_HEAD' /tmp/m19i-alembic-current.txt" || {
    rc=$?
    echo "FAIL: Alembic current check failed or timed out (exit=$rc)" >&2
    exit "$rc"
}
echo "PASS: database current at $EXPECTED_HEAD"
echo "PASS: Alembic $EXPECTED_HEAD"
grep -q sponsors_web_router app/main.py; grep -q game_sponsors_router app/main.py; grep -q game_sponsor_presentation_router app/main.py; grep -q 'id="sponsor-zone"' templates/overlay/game.html; grep -q sponsor_impressions app/models/sponsor_impression.py; grep -q game_broadcast_presentations app/models/game_broadcast_presentation.py; grep -q '/stream/games/' static/js/games/detail.js; echo 'PASS: M19-B through M19-H structural integration'
# Historical M19-B pins migration 0027 and is intentionally not run against cumulative 0031.
bash scripts/validate_m19a.sh
bash scripts/validate_m19f.sh
bash scripts/validate_m19g.sh
bash scripts/validate_m19h.sh
git diff --check; git diff --cached --check; echo 'PASS: git diff checks'
echo 'M19-I LOCAL VALIDATION: PASS'
