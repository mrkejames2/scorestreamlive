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

run_harness() {
  local label="$1"
  local script="$2"
  local out rc cp cf

  out=$(mktemp)

  echo ""
  echo "========================================"
  echo "Running ${label}"
  echo "========================================"

  set +e
  BASE_URL="$BASE_URL" "$script" 2>&1 | tee "$out"
  rc=${PIPESTATUS[0]}
  set -e

  cp=$(grep -oP 'Passed: \K[0-9]+' "$out" | tail -1 || true)
  cf=$(grep -oP 'Failed: \K[0-9]+' "$out" | tail -1 || true)

  cp="${cp:-0}"
  cf="${cf:-0}"

  PASS=$((PASS + cp))
  FAIL=$((FAIL + cf))

  rm -f "$out"

  if [ "$rc" -eq 0 ]; then
    pass "${label} process passed"
  else
    fail "${label} process failed with exit code ${rc}"
  fi
}

echo "========================================"
echo "ScoreStreamLive M11-G Final Broadcast Release Gate"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /health/live \
  /health/ready \
  /info \
  /static/js/control/clock.js \
  /static/js/control/control.js \
  /static/js/overlay/overlay.js \
  /static/css/overlay.css
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

# Focused cross-display clock architecture certification.
if [ -x "./scripts/validate_m11f_clock_sync.sh" ]; then
  run_harness "M11-F cross-display clock sync" "./scripts/validate_m11f_clock_sync.sh"
else
  fail "M11-F cross-display clock sync validator missing"
fi

# Full M11 cumulative regression.
run_harness "M11-F cumulative regression" "./scripts/validate_m11f.sh"

echo ""
echo "========================================"
echo "M11-G Static Architecture Certification"
echo "========================================"

CONTROL_CLOCK=$(curl -fsS "${BASE_URL}/static/js/control/clock.js")
CONTROL_JS=$(curl -fsS "${BASE_URL}/static/js/control/control.js")
OVERLAY_JS=$(curl -fsS "${BASE_URL}/static/js/overlay/overlay.js")
OVERLAY_CSS=$(curl -fsS "${BASE_URL}/static/css/overlay.css")

grep -Fq 'performance.now()' <<<"$CONTROL_CLOCK" \
  && pass "Control Center uses monotonic clock anchor" \
  || fail "Control Center monotonic clock anchor missing"

grep -Fq 'setInterval(resyncAuthoritativeClock, 5000)' <<<"$CONTROL_JS" \
  && pass "Control Center has 5-second authoritative clock resync" \
  || fail "Control Center 5-second authoritative clock resync missing"

grep -Fq 'CLOCK_RESYNC_MS = 5000' <<<"$OVERLAY_JS" \
  && pass "Overlay has 5-second authoritative clock resync" \
  || fail "Overlay 5-second authoritative clock resync missing"

grep -Fq 'showGoalBanner' <<<"$OVERLAY_JS" \
  && pass "Goal presentation preserved" \
  || fail "Goal presentation missing"

grep -Fq 'showMatchStateBanner' <<<"$OVERLAY_JS" \
  && pass "Match-state presentation preserved" \
  || fail "Match-state presentation missing"

grep -Fq 'lastPresentedPhase' <<<"$OVERLAY_JS" \
  && pass "Lifecycle replay protection preserved" \
  || fail "Lifecycle replay protection missing"

grep -Fq 'lastGoalEventId' <<<"$OVERLAY_JS" \
  && pass "Goal replay protection preserved" \
  || fail "Goal replay protection missing"

grep -Fq 'background: transparent' <<<"$OVERLAY_CSS" \
  && pass "Transparent broadcast canvas preserved" \
  || fail "Transparent broadcast canvas missing"

if grep -Eq 'socket\.on\(["'\'']clock:tick' <<<"$CONTROL_JS" "$OVERLAY_JS"; then
  fail "clock:tick consumer detected"
else
  pass "No clock:tick consumer"
fi

if grep -Eq 'method:\s*["'\'']POST["'\'']' <<<"$OVERLAY_JS"; then
  fail "Overlay mutation implementation detected"
else
  pass "Overlay remains read-only"
fi

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M11-G FINAL ACCEPTANCE PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  echo "MILESTONE 11 AUTOMATED RELEASE GATE COMPLETE"
  exit 0
else
  echo "M11-G FINAL ACCEPTANCE FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
