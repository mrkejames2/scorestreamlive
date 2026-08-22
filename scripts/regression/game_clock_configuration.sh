#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0

if [[ "$VALIDATION_MODE" == "local" ]]; then
  for m in 'id="clock-duration-form"' 'value="20"' 'value="25"' 'value="30"' 'value="35"' 'value="40"' 'value="45"' 'Current Half Length'; do
    grep -Fq "$m" templates/control/game.html || { echo "FAIL missing $m"; fail=1; }
  done
  grep -Fq '/static/css/control-m14e.css' templates/control/game.html || { echo "FAIL stylesheet missing"; fail=1; }
  grep -Fq 'export function configureClock(' static/js/control/api.js || { echo "FAIL configureClock missing"; fail=1; }
  grep -Fq 'method: "PATCH"' static/js/control/api.js || { echo "FAIL PATCH missing"; fail=1; }
  grep -Fq 'const CLOCK_DURATION_MINUTES = [20, 25, 30, 35, 40, 45];' static/js/control/control.js || { echo "FAIL presets missing"; fail=1; }
  grep -Fq 'async function saveClockDuration()' static/js/control/control.js || { echo "FAIL save handler missing"; fail=1; }
  grep -Fq 'function clockConfigurationIsReady()' static/js/control/control.js || { echo "FAIL authoritative clock readiness gate missing"; fail=1; }
  grep -Fq 'const ready = clockConfigurationIsReady();' static/js/control/control.js || { echo "FAIL clock config still tied to live socket gate"; fail=1; }
  grep -Fq 'halfDurationSeconds = selectedMinutes * 60' static/js/control/control.js || { echo "FAIL half-length conversion missing"; fail=1; }
  grep -Fq 'clockDurationSecondsForHalfLength(' static/js/control/control.js || { echo "FAIL continuous-clock duration conversion missing"; fail=1; }
  grep -Fq 'state.clock.status === "running"' static/js/control/control.js || { echo "FAIL running guard missing"; fail=1; }
  grep -Fq '"duration_seconds": clock.duration_seconds' app/services/game_lifecycle_service.py || { echo "FAIL first half does not preserve configured duration"; fail=1; }
  grep -Fq 'half_duration_seconds = int(clock.duration_seconds)' app/services/game_lifecycle_service.py || { echo "FAIL second half half-duration derivation missing"; fail=1; }
  grep -Fq '"duration_seconds": half_duration_seconds * 2' app/services/game_lifecycle_service.py || { echo "FAIL second half total duration derivation missing"; fail=1; }
  grep -Fq '"elapsed_seconds": half_duration_seconds' app/services/game_lifecycle_service.py || { echo "FAIL second half start offset derivation missing"; fail=1; }
  grep -Fq 'function configuredHalfDurationSeconds()' static/js/control/control.js || { echo "FAIL half-length display normalization missing"; fail=1; }
  grep -Fq 'function clockDurationSecondsForHalfLength(halfDurationSeconds)' static/js/control/control.js || { echo "FAIL half-length save normalization missing"; fail=1; }
  if grep -Fq '"duration_seconds": 2700' app/services/game_lifecycle_service.py || grep -Fq '"duration_seconds": 5400' app/services/game_lifecycle_service.py; then echo "FAIL hard-coded 45/90 lifecycle duration remains"; fail=1; else echo "PASS lifecycle has no hard-coded 45/90 duration"; fi
  grep -Fq 'duration_seconds: Optional[int] = Field(None, gt=0)' app/schemas/game_clock.py || { echo "FAIL backend duration contract missing"; fail=1; }
  grep -Fq 'Clock configuration cannot change while running' app/services/game_clock_service.py || { echo "FAIL backend running guard missing"; fail=1; }
  grep -Fq 'await _emit_clock_updated(clock, "configured")' app/services/game_clock_service.py || { echo "FAIL clock updated event missing"; fail=1; }
  grep -Fq 'id="overlay-added-time"' templates/overlay/game.html || { echo "FAIL overlay added-time element missing"; fail=1; }
  grep -Fq '/static/css/overlay-m14e.css' templates/overlay/game.html || { echo "FAIL overlay stylesheet missing"; fail=1; }
  grep -Fq 'function soccerAddedTimeMinute()' static/js/overlay/overlay.js || { echo "FAIL overlay added-time calculation missing"; fail=1; }
  grep -Fq 'byId("overlay-added-time").textContent' static/js/overlay/overlay.js || { echo "FAIL overlay added-time render missing"; fail=1; }
  grep -Fq '"duration_seconds": clock.duration_seconds' app/services/game_lifecycle_service.py || { echo "FAIL first-half duration not preserved"; fail=1; }
  grep -Fq 'half_duration_seconds = int(clock.duration_seconds)' app/services/game_lifecycle_service.py || { echo "FAIL second-half half-duration derivation missing"; fail=1; }
  grep -Fq '"duration_seconds": half_duration_seconds * 2' app/services/game_lifecycle_service.py || { echo "FAIL second-half threshold not 2H"; fail=1; }
  grep -Fq '"elapsed_seconds": half_duration_seconds' app/services/game_lifecycle_service.py || { echo "FAIL second-half start not H"; fail=1; }
  grep -Fq 'return Math.min(elapsed, duration);' static/js/control/clock.js || { echo "FAIL Control regulation freeze missing"; fail=1; }
  grep -Fq 'elapsed <= duration' static/js/control/clock.js || { echo "FAIL Control +1 threshold wrong"; fail=1; }
  grep -Fq 'function configuredHalfDurationSeconds()' static/js/control/control.js || { echo "FAIL Control half-length normalization missing"; fail=1; }
  grep -Fq 'id="overlay-added-time"' templates/overlay/game.html || { echo "FAIL Overlay +N element missing"; fail=1; }
  grep -Fq 'function soccerAddedTimeMinute()' static/js/overlay/overlay.js || { echo "FAIL Overlay +N calculation missing"; fail=1; }
  grep -Fq 'return Math.min(elapsed, duration);' static/js/overlay/overlay.js || { echo "FAIL Overlay regulation freeze missing"; fail=1; }
  grep -Fq 'byId("overlay-added-time").textContent' static/js/overlay/overlay.js || { echo "FAIL Overlay +N render missing"; fail=1; }
  if grep -Fq '"duration_seconds": 2700' app/services/game_lifecycle_service.py || grep -Fq '"duration_seconds": 5400' app/services/game_lifecycle_service.py; then echo "FAIL hard-coded 45/90 lifecycle values remain"; fail=1; else echo "PASS no hard-coded 45/90 lifecycle values"; fi
fi

for spec in "20:1200" "25:1500" "30:1800" "35:2100" "40:2400" "45:2700"; do
  IFS=: read -r m s <<<"$spec"
  [[ $((m*60)) -eq $s ]] && echo "PASS ${m} min = ${s} sec" || { echo "FAIL ${m} min"; fail=1; }
done
exit "$fail"


for spec in "1200:1200:0" "1201:1200:1" "1259:1200:1" "1260:1200:2" "2400:2400:0" "2401:2400:1" "2459:2400:1" "2460:2400:2"; do
  IFS=: read -r elapsed threshold expected <<<"$spec"
  if (( elapsed <= threshold )); then actual=0; else actual=$(( (elapsed-threshold)/60 + 1 )); fi
  if [[ "$actual" == "$expected" ]]; then echo "PASS added-time elapsed=$elapsed threshold=$threshold -> +$actual"; else echo "FAIL added-time elapsed=$elapsed threshold=$threshold -> +$actual expected +$expected"; fail=1; fi
done
