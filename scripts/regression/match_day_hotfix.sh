#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0

check(){ local d="$1"; local p="$2"; local f="$3"; if grep -Fq "$p" "$f"; then echo "PASS $d"; else echo "FAIL $d"; fail=1; fi; }

if [[ "$VALIDATION_MODE" == "local" ]]; then
  check "broadcast migration" 'sa.Column("broadcast_message"' alembic/versions/20260822_0009_add_game_broadcast_message.py
  check "broadcast model field" 'broadcast_message:' app/models/game.py
  check "broadcast schema" 'class GameBroadcastMessageUpdate' app/schemas/game.py
  check "broadcast response field" 'broadcast_message: Optional[str]' app/schemas/game.py
  check "broadcast endpoint" '/{game_id}/broadcast-message' app/api/games.py
  check "pause client API" 'export function pauseClock(' static/js/control/api.js
  check "resume client API" 'export function resumeClock(' static/js/control/api.js
  check "pause/resume button" 'id="clock-pause-resume-button"' templates/control/game.html
  check "weather delay shortcut" 'id="broadcast-message-weather"' templates/control/game.html
  check "overlay banner" 'id="broadcast-message-banner"' templates/overlay/game.html
  check "overlay game update socket" 'socket.on("game:updated"' static/js/overlay/overlay.js

  if grep -Fq 'return Math.min(elapsed, duration);' static/js/control/clock.js; then echo "FAIL Control timer still clamps"; fail=1; else echo "PASS Control timer continues past regulation"; fi
  if grep -Fq 'return Math.min(elapsed, duration);' static/js/overlay/overlay.js; then echo "FAIL Overlay timer still clamps"; fail=1; else echo "PASS Overlay timer continues past regulation"; fi
fi

curl -fsS "${BASE_URL}/games" >/dev/null || { echo "FAIL /games"; fail=1; }
exit "$fail"
