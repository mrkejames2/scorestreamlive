#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

if [[ -f scripts/lib/validation.sh ]]; then
  source scripts/lib/validation.sh
  validation_init || exit $?
fi

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
VALIDATION_MODE="${VALIDATION_MODE:-local}"
fail=0

pass() { echo "PASS $1"; }
fail_check() { echo "FAIL $1"; fail=1; }

require_file() {
  if [[ -f "$1" ]]; then pass "file $1"; else fail_check "missing $1"; fi
}

require_text() {
  local file="$1" text="$2" label="$3"
  if grep -Fq "$text" "$file"; then pass "$label"; else fail_check "$label"; fi
}

require_file app/sockets.py
require_file static/js/control/socket.js
require_file static/js/overlay/socket-context.js
require_file templates/overlay/game.html
require_file docs/milestones/m16/M16B_SOCKET_RELIABILITY_ISOLATION.md
require_file docs/milestones/m16/M16B_HF1_CONTROL_SUBSCRIPTION_REPAIR.md

require_text app/sockets.py 'class GameScopedAsyncServer' 'server-enforced match-day scoping'
require_text app/sockets.py 'MATCH_DAY_EVENTS' 'known match-day event registry'
require_text app/sockets.py 'game:{game_id}:{suffix}' 'game and audience room naming'
require_text app/sockets.py 'audience == "control"' 'control subscription authorization branch'
require_text app/sockets.py 'can_operate_game' 'Control Center subscription uses game authorization'
require_text app/sockets.py 'resolve_session_user' 'socket session resolves persistent login'
require_text app/sockets.py 'await sio.enter_room' 'game room membership established'
require_text app/sockets.py 'await sio.leave_room' 'stale game room membership removed'
require_text app/sockets.py '@sio.on("game:subscribe")' 'explicit Control Center game subscription event'
require_text app/sockets.py 'room=game_room(game_id, "overlay")' 'public room delivery scope'
require_text app/sockets.py 'room=game_room(game_id, "control")' 'control room delivery scope'
require_text app/sockets.py 'Blocked unscoped match-day Socket.IO event' 'unscoped match-day broadcasts blocked'

# HF1: current clients subscribe in the handshake, while a narrow, authorized
# Referer compatibility path repairs already-cached pre-M16-B Control clients.
require_text static/js/control/socket.js 'auth: {' 'Control Center sends socket handshake context'
require_text static/js/control/socket.js 'game_id: String(gameId)' 'Control handshake identifies current game'
require_text static/js/control/socket.js 'audience: "control"' 'Control handshake requests privileged audience'
require_text static/js/control/socket.js '"game:subscribe"' 'Control Center retains explicit idempotent subscription'
require_text static/js/control/socket.js 'await subscribeToControlGame(socket, gameId);' 'Control Center confirms room before recovery'
require_text static/js/control/socket.js 'await recoverAuthoritativeState();' 'Control Center reconnect reconciles authority'
require_text static/js/control/socket.js 'isCurrentGame(payload, gameId)' 'Control Center retains payload defense-in-depth'
require_text app/sockets.py 'def _control_game_id_from_environ' 'HF1 cached-Control compatibility detector exists'
require_text app/sockets.py 'prefix = "/control/games/"' 'HF1 compatibility is limited to Control Center route'
require_text app/sockets.py 'initial_subscription = {' 'HF1 server establishes inferred Control subscription'
require_text app/sockets.py '"audience": "control"' 'HF1 inferred subscription uses control audience'
require_text app/sockets.py 'result = await _subscribe_game(sid, initial_subscription)' 'HF1 compatibility still uses normal authorization path'
require_text app/sockets.py 'return False' 'denied initial subscription does not remain live unscoped'

require_text static/js/overlay/socket-context.js 'audience: "overlay"' 'Overlay handshake requests public audience'
require_text static/js/overlay/socket-context.js 'game_id: String(gameId)' 'Overlay handshake scopes current game'
require_text templates/overlay/game.html '/static/js/overlay/socket-context.js' 'Overlay loads room context before overlay application'
require_text static/js/overlay/overlay.js '/api/public/games/${gameId}/overlay-state' 'Overlay recovery remains public authoritative snapshot'
require_text static/js/overlay/overlay.js 'await recoverAuthoritativeState();' 'Overlay reconnect still reconciles authority'
require_text static/js/overlay/overlay.js 'belongsToThisGame(payload)' 'Overlay retains payload defense-in-depth'

# The legacy diagnostic broadcast is intentionally not a match-day event.
if grep -Fq '"test:broadcast"' app/sockets.py; then
  pass 'legacy socket diagnostic retained outside match-day room contract'
else
  fail_check 'legacy socket diagnostic retained outside match-day room contract'
fi

# M16-B must not introduce an external socket broker or alternate authority.
for forbidden in redis nats kafka; do
  if grep -Eiq "(^|[^[:alnum:]_])${forbidden}([^[:alnum:]_]|$)" app/sockets.py; then
    fail_check "no ${forbidden} dependency in socket server"
  else
    pass "no ${forbidden} dependency in socket server"
  fi
done

# Production-safe runtime smoke only: no synthetic mutations or socket events.
if command -v curl >/dev/null 2>&1; then
  if curl -fsS --max-time 10 "$BASE_URL/health/live" >/dev/null; then
    pass "health live reachable"
  else
    fail_check "health live reachable"
  fi
fi

exit "$fail"
