#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL

PASS=0
FAIL=0
pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "ScoreStreamLive M12-D3 Inline Team Creation + Branding UI"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /games \
  /static/css/games.css \
  /static/css/games-d3.css \
  /static/js/games/index.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

PAGE=$(curl -fsS "${BASE_URL}/games")
JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/games-d3.css")

echo ""
echo "========================================"
echo "M12-D3 Static Capability Checks"
echo "========================================"

grep -Fq 'M12-D3' <<<"$PAGE" \
  && pass "M12-D3 Game Setup presentation present" \
  || fail "M12-D3 presentation marker missing"

for id in \
  home-create-team-button \
  away-create-team-button \
  home-create-team-panel \
  away-create-team-panel \
  home-new-team-name \
  away-new-team-name \
  home-new-team-logo \
  away-new-team-logo \
  home-logo-preview \
  away-logo-preview \
  home-new-team-primary-color \
  away-new-team-primary-color \
  home-new-team-secondary-color \
  away-new-team-secondary-color
do
  grep -Fq "id=\"${id}\"" <<<"$PAGE" \
    && pass "UI contains #${id}" \
    || fail "UI missing #${id}"
done

grep -Fq '/static/css/games-d3.css' <<<"$PAGE" \
  && pass "M12-D3 dedicated CSS loaded" \
  || fail "M12-D3 dedicated CSS missing"

grep -Fq 'async function createInlineTeam' <<<"$JS" \
  && pass "Inline Team creation orchestration exists" \
  || fail "Inline Team creation orchestration missing"

grep -Fq 'api("/api/teams"' <<<"$JS" \
  && pass "Inline Team creation uses existing Team REST API" \
  || fail "Existing Team REST API not used"

grep -Fq 'FormData' <<<"$JS" \
  && grep -Fq '/logo' <<<"$JS" \
  && pass "Optional logo uses M12-D2 multipart upload API" \
  || fail "M12-D2 logo upload orchestration missing"

grep -Fq 'addTeamToLocalState' <<<"$JS" \
  && grep -Fq 'selectTeam(side, team.id)' <<<"$JS" \
  && pass "New Team becomes immediately selectable/selected" \
  || fail "Immediate new-Team selection behavior missing"

grep -Fq 'URL.createObjectURL' <<<"$JS" \
  && grep -Fq 'URL.revokeObjectURL' <<<"$JS" \
  && pass "Logo preview lifecycle exists" \
  || fail "Logo preview lifecycle missing"

grep -Fq 'MAX_LOGO_BYTES = 2 * 1024 * 1024' <<<"$JS" \
  && pass "Client preflight mirrors 2 MiB logo limit" \
  || fail "Client logo size preflight missing"

grep -Fq 'image/png' <<<"$JS" \
  && grep -Fq 'image/jpeg' <<<"$JS" \
  && grep -Fq 'image/webp' <<<"$JS" \
  && pass "Client preflight mirrors supported logo formats" \
  || fail "Client logo type preflight missing"

grep -Fq '.inline-team-create' <<<"$CSS" \
  && grep -Fq '.logo-preview' <<<"$CSS" \
  && grep -Fq '.color-field-grid' <<<"$CSS" \
  && pass "Inline Team branding UI styling exists" \
  || fail "Inline Team branding styling missing"

# Preserve M12-A/B/C architecture.
grep -Fq 'const MAX_VISIBLE_GAMES = 25;' <<<"$JS" \
  && pass "M12-A recent-game cap preserved" \
  || fail "M12-A recent-game cap regressed"

grep -Fq 'const MAX_CONCURRENT_GAMES = 6;' <<<"$JS" \
  && grep -Fq 'mapWithConcurrency' <<<"$JS" \
  && pass "M12-A bounded hydration preserved" \
  || fail "M12-A bounded hydration regressed"

grep -Fq 'const MAX_TEAM_RESULTS = 12;' <<<"$JS" \
  && pass "M12-B bounded Team search preserved" \
  || fail "M12-B bounded Team search regressed"

grep -Fq 'ensureLifecycleInitialized' <<<"$JS" \
  && grep -Fq 'ensureClockInitialized' <<<"$JS" \
  && grep -Fq 'initializeCreatedGame' <<<"$JS" \
  && pass "M12-C launch initialization preserved" \
  || fail "M12-C launch initialization regressed"

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "clock:tick consumer introduced"
else
  pass "No clock:tick consumer introduced"
fi

echo ""
echo "========================================"
echo "Running M12-D2 regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12d2.sh
D2_RC=$?
set -e

[ "$D2_RC" -eq 0 ] \
  && pass "M12-D2 regression passed" \
  || fail "M12-D2 regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-D3 VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-D3 VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
