#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
EXPECTED_HEAD="${EXPECTED_ALEMBIC_HEAD:-20260920_0031}"; BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
echo '=== ScoreStreamLive Final M19 Release Gate ==='
git diff --check; git diff --cached --check; echo 'PASS: diff checks'
BASE_URL="$BASE_URL" EXPECTED_ALEMBIC_HEAD="$EXPECTED_HEAD" bash scripts/validate_m19i.sh
BASE_URL="$BASE_URL" EXPECTED_ALEMBIC_HEAD="$EXPECTED_HEAD" bash scripts/production_m19i_preflight.sh
echo 'AUTOMATED M19 RELEASE GATE: PASS'
echo 'This does NOT by itself declare production acceptance.'
echo '[ ] deployed SHA matches approved M19-I commit'
echo "[ ] production Alembic revision is $EXPECTED_HEAD"
echo '[ ] production health/live and health/ready pass'
echo '[ ] sponsor CRUD/artwork/assignment and Sponsor Zone pass'
echo '[ ] sponsor tracking/reporting passes'
echo '[ ] Welcome upload/enable/remove and Welcome -> Live pass'
echo '[ ] public /stream, /overlay, /broadcast routes pass'
echo '[ ] scoreboard/clock/roster/scoring regression passes'
echo '[ ] POST production baseline captured/reviewed'
