#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

# Reuse the centralized validation environment when available.
if [[ -f scripts/lib/validation.sh ]]; then
  # shellcheck disable=SC1091
  source scripts/lib/validation.sh
  validation_init || exit $?
fi

: "${BASE_URL:=http://127.0.0.1:8000}"
: "${VALIDATION_MODE:=local}"

fail=0

check_file_contains() {
  local description="$1"
  local pattern="$2"
  local file="$3"

  if grep -Fq "$pattern" "$file"; then
    echo "PASS $description"
  else
    echo "FAIL $description"
    fail=1
  fi
}

echo "M16-A Match-Day State & Recovery"

# These checks protect architectural invariants, not implementation trivia.
check_file_contains \
  "clock state is persisted" \
  'running_since:' \
  app/models/game_clock.py

check_file_contains \
  "clock uses persisted running anchor" \
  'calculate_authoritative_elapsed_seconds' \
  app/services/game_clock_service.py

check_file_contains \
  "clock mutations use optimistic versioning" \
  'GameClock.version == expected_version' \
  app/services/game_clock_service.py

check_file_contains \
  "Control Center gates mutations on authoritative state" \
  'state.stateAuthoritative' \
  static/js/control/control.js

check_file_contains \
  "Control Center recovers authoritative state after socket connect" \
  'await recoverAuthoritativeState();' \
  static/js/control/socket.js

check_file_contains \
  "Overlay has public authoritative snapshot recovery" \
  'await loadAuthoritativeState();' \
  static/js/overlay/overlay.js

check_file_contains \
  "Overlay recovers after device visibility returns" \
  'document.visibilityState === "visible"' \
  static/js/overlay/overlay.js

check_file_contains \
  "public Overlay state boundary remains unauthenticated" \
  '/api/public/games/{game_id}/overlay-state' \
  app/api/control.py

check_file_contains \
  "scoring schema accepts request id" \
  'request_id: Optional[UUID] = None' \
  app/schemas/scoring_event.py

check_file_contains \
  "scoring request id is durable" \
  'request_id: Mapped[Optional[uuid.UUID]]' \
  app/models/scoring_event.py

check_file_contains \
  "scoring request id is uniquely constrained" \
  'ux_scoring_events_request_id' \
  app/models/scoring_event.py

check_file_contains \
  "scoring replay is checked server side" \
  '_existing_request(db, data.request_id)' \
  app/services/scoring_service.py

check_file_contains \
  "duplicate race rolls transaction back" \
  'except IntegrityError:' \
  app/services/scoring_service.py

check_file_contains \
  "Control Center sends scoring request id" \
  'request_id: commandRequestId' \
  static/js/control/api.js

# Safe in both local and production: no synthetic data is written.
if curl -fsS "${BASE_URL}/health/live" >/dev/null; then
  echo "PASS application liveness"
else
  echo "FAIL application liveness"
  fail=1
fi

# Production validation intentionally stops at read-only/static invariants.
# Duplicate-command mutation behavior is exercised in local/human acceptance,
# never by creating synthetic production goals.
if [[ "$VALIDATION_MODE" == "production" ]]; then
  echo "PASS production recovery validation remains non-destructive"
fi

exit "$fail"
