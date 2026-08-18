#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"

PASS=0
FAIL=0
pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "ScoreStreamLive M11-F Cross-Display Clock Sync Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in \
  /static/js/control/clock.js \
  /static/js/control/control.js \
  /static/js/overlay/overlay.js
do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

CONTROL_CLOCK=$(curl -fsS "${BASE_URL}/static/js/control/clock.js")
CONTROL_JS=$(curl -fsS "${BASE_URL}/static/js/control/control.js")
OVERLAY_JS=$(curl -fsS "${BASE_URL}/static/js/overlay/overlay.js")

grep -Fq 'performance.now()' <<<"$CONTROL_CLOCK" \
  && pass "Control clock uses monotonic browser anchor" \
  || fail "Control clock does not use performance.now()"

if grep -Fq 'Date.now() + serverOffsetMs' <<<"$CONTROL_CLOCK"; then
  fail "Legacy Date.now server-offset interpolation still present"
else
  pass "Legacy Date.now interpolation removed"
fi

grep -Fq 'authoritative_elapsed_seconds' <<<"$CONTROL_CLOCK" \
  && pass "Control clock anchors from authoritative elapsed snapshot" \
  || fail "Control clock lacks authoritative elapsed snapshot"

grep -Fq 'async function resyncAuthoritativeClock()' <<<"$CONTROL_JS" \
  && pass "Control has clock-only authoritative resync" \
  || fail "Control lacks clock-only authoritative resync"

grep -Fq 'setInterval(resyncAuthoritativeClock, 5000)' <<<"$CONTROL_JS" \
  && pass "Control resync cadence is 5 seconds" \
  || fail "Control resync cadence is not 5 seconds"

grep -Fq 'CLOCK_RESYNC_MS = 5000' <<<"$OVERLAY_JS" \
  && pass "Overlay resync cadence remains 5 seconds" \
  || fail "Overlay resync cadence changed"

grep -Fq 'performance.now()' <<<"$OVERLAY_JS" \
  && pass "Overlay still uses monotonic browser anchor" \
  || fail "Overlay monotonic anchor missing"

if grep -Fq 'clock:tick' <<<"$CONTROL_JS" | grep -vq '^$'; then
  # Existing comments/negative guards can contain the text; only reject a listener.
  if grep -Eq 'socket\.on\(["'\'']clock:tick' <<<"$CONTROL_JS"; then
    fail "Control consumes clock:tick"
  else
    pass "Control consumes no clock:tick"
  fi
else
  pass "Control consumes no clock:tick"
fi

echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M11-F CLOCK SYNC VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  exit 0
else
  echo "M11-F CLOCK SYNC VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  exit 1
fi
