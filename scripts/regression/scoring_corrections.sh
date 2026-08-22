#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0
check(){ local d="$1" p="$2" f="$3"; if grep -Fq "$p" "$f"; then echo "PASS $d"; else echo "FAIL $d"; fail=1; fi; }
if [[ "$VALIDATION_MODE" == "local" ]]; then
 check "update schema" "class ScoringEventUpdate" app/schemas/scoring_event.py
 check "update service" "async def update_scoring_event_scorer(" app/services/scoring_service.py
 check "delete service" "async def delete_scoring_event(" app/services/scoring_service.py
 check "correction API" "export function updateScoringEventScorer(" static/js/control/api.js
 check "delete API" "export function deleteScoringEvent(" static/js/control/api.js
 check "overlay correction" 'socket.on("scoring_event:corrected"' static/js/overlay/overlay.js
 check "1 minute option" 'value="1"><span>1 min (Test)</span>' templates/control/game.html
fi
curl -fsS "${BASE_URL}/games" >/dev/null || { echo "FAIL /games"; fail=1; }
exit "$fail"
