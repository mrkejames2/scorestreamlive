#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

code="$(curl -sS -o "$tmp" -w "%{http_code}" "${BASE_URL}/static/js/games/classification.js" || true)"
if [[ "$code" == "200" ]]; then
  echo "PASS classification module HTTP 200"
else
  echo "FAIL classification module HTTP ${code}"
  fail=1
fi

for marker in \
  'UPCOMING: "upcoming"' \
  'LIVE: "live"' \
  'COMPLETED: "completed"' \
  'CANCELLED: "cancelled"' \
  'lifecyclePhase === "full_time"' \
  'LIVE_PHASES.has(lifecyclePhase)' \
  'lifecyclePhase === "pregame"' \
  'clockStatus === "running"' \
  'gameStatus === "completed"' \
  'gameStatus === "live"'
do
  if grep -Fq "$marker" "$tmp"; then
    echo "PASS classification contract: $marker"
  else
    echo "FAIL classification contract missing: $marker"
    fail=1
  fi
done

if [[ "$VALIDATION_MODE" == "local" ]]; then
  v_expect_file_contains "static/js/games/index.js" 'from "./classification.js"' || fail=1
  v_expect_file_contains "static/js/games/index.js" 'classifyGame(game, lifecycle, clock)' || fail=1
  v_expect_file_contains "static/js/games/index.js" 'GameLibraryClassification.COMPLETED' || fail=1
  v_expect_file_contains "static/js/games/index.js" 'GameLibraryClassification.LIVE' || fail=1

  if grep -Fq 'function isCompleted(' static/js/games/index.js \
      || grep -Fq 'function isActive(' static/js/games/index.js; then
    echo "FAIL legacy ad-hoc Game classification helpers remain"
    fail=1
  else
    echo "PASS legacy Game classification helpers removed"
  fi

  if find alembic/versions -maxdepth 1 -type f \
      \( -iname '*m14*' -o -iname '*0014*' \) | grep -q .; then
    echo "FAIL unexpected M14 database migration detected"
    fail=1
  else
    echo "PASS no M14 database migration"
  fi
fi

python3 - <<'PY' || fail=1
U,L,C,X='upcoming','live','completed','cancelled'
LP={'first_half','halftime','second_half'}

def classify(gs='', p='', cs=''):
    gs=gs.lower(); p=p.lower(); cs=cs.lower()
    if gs == 'cancelled': return X
    if p == 'full_time': return C
    if p in LP: return L
    if p == 'pregame': return U
    if cs == 'running': return L
    if gs == 'completed': return C
    if gs == 'live': return L
    return U

cases = [
    ('pregame', classify(p='pregame'), U),
    ('first_half', classify(p='first_half'), L),
    ('halftime', classify(p='halftime'), L),
    ('second_half', classify(p='second_half'), L),
    ('full_time', classify(p='full_time'), C),
    ('cancelled', classify(gs='cancelled', p='pregame'), X),
    ('clock-running fallback', classify(cs='running'), L),
    ('completed fallback', classify(gs='completed'), C),
    ('live fallback', classify(gs='live'), L),
    ('scheduled fallback', classify(gs='scheduled'), U),
]
for label, actual, expected in cases:
    if actual != expected:
        raise SystemExit(f"FAIL {label}: {actual} != {expected}")
    print(f"PASS classification case: {label} -> {actual}")
PY

exit "$fail"
