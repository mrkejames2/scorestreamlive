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
echo "ScoreStreamLive M12-D4 Branded Game Setup + Game Management"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /games \
  /static/css/games.css \
  /static/css/games-d3.css \
  /static/css/games-d4.css \
  /static/js/games/index.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

PAGE=$(curl -fsS "${BASE_URL}/games")
JS=$(curl -fsS "${BASE_URL}/static/js/games/index.js")
CSS=$(curl -fsS "${BASE_URL}/static/css/games-d4.css")

echo ""
echo "========================================"
echo "M12-D4 Branding Presentation Checks"
echo "========================================"

grep -Fq 'M12-D4' <<<"$PAGE" \
  && pass "M12-D4 presentation marker present" \
  || fail "M12-D4 presentation marker missing"

grep -Fq '/static/css/games-d4.css' <<<"$PAGE" \
  && pass "M12-D4 dedicated CSS loaded" \
  || fail "M12-D4 dedicated CSS missing"

for selector in \
  home-selected-brand-logo \
  away-selected-brand-logo
do
  grep -Fq "id=\"${selector}\"" <<<"$PAGE" \
    && pass "Selected-Team branding includes #${selector}" \
    || fail "Selected-Team branding missing #${selector}"
done

grep -Fq 'home-team-logo' <<<"$PAGE" \
  && grep -Fq 'away-team-logo' <<<"$PAGE" \
  && pass "Game cards contain Home/Away logo presentation" \
  || fail "Game-card logo presentation missing"

grep -Fq 'function setBrandIcon' <<<"$JS" \
  && pass "Shared Team brand-icon renderer exists" \
  || fail "Shared Team brand-icon renderer missing"

grep -Fq 'function teamInitials' <<<"$JS" \
  && pass "No-logo initials fallback exists" \
  || fail "No-logo initials fallback missing"

grep -Fq 'function normalizedTeamColor' <<<"$JS" \
  && pass "Team color normalization exists" \
  || fail "Team color normalization missing"

grep -Fq 'function applySelectedTeamBrand' <<<"$JS" \
  && pass "Selected Team branding rendering exists" \
  || fail "Selected Team branding rendering missing"

grep -Fq 'teamResultButton' <<<"$JS" \
  && grep -Fq 'teamBrandNode(team)' <<<"$JS" \
  && grep -Fq 'teamColorSwatches(team)' <<<"$JS" \
  && pass "Team search results render logo + colors" \
  || fail "Branded Team search-result rendering missing"

grep -Fq 'homeTeam?.primary_color' <<<"$JS" \
  && grep -Fq 'awayTeam?.primary_color' <<<"$JS" \
  && pass "Game cards consume persisted Team colors" \
  || fail "Game cards do not consume Team colors"

grep -Fq 'homeTeam' <<<"$JS" \
  && grep -Fq 'home-team-logo' <<<"$JS" \
  && grep -Fq 'awayTeam' <<<"$JS" \
  && grep -Fq 'away-team-logo' <<<"$JS" \
  && pass "Game cards consume Team logo state" \
  || fail "Game cards do not consume Team logo state"

grep -Fq '.team-brand-icon' <<<"$CSS" \
  && grep -Fq '.team-search-result-branded' <<<"$CSS" \
  && grep -Fq '.game-team-brand' <<<"$CSS" \
  && pass "Branding presentation CSS exists" \
  || fail "Branding presentation CSS missing"

grep -Fq 'var(--home-primary)' <<<"$CSS" \
  && grep -Fq 'var(--away-primary)' <<<"$CSS" \
  && pass "Game cards expose team-color accents" \
  || fail "Game-card color accents missing"

# D4 remains presentation-only.
if grep -Eq 'method:[[:space:]]*"(PATCH|PUT|DELETE)"|method:[[:space:]]*'\''(PATCH|PUT|DELETE)'\''' <<<"$JS"; then
  fail "D4 introduced forbidden new mutation method"
else
  pass "D4 introduces no PATCH/PUT/DELETE mutation"
fi

if grep -Fq 'clock:tick' <<<"$JS"; then
  fail "clock:tick consumer introduced"
else
  pass "No clock:tick consumer introduced"
fi

echo ""
echo "========================================"
echo "Running M12-D3 regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12d3.sh
D3_RC=$?
set -e

[ "$D3_RC" -eq 0 ] \
  && pass "M12-D3 regression passed" \
  || fail "M12-D3 regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-D4 VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-D4 VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
