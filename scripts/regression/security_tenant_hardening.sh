#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail(){ echo "FAIL: $*"; exit 1; }
need(){ grep -Fq "$2" "$1" || fail "$1 missing: $2"; }

for f in app/api/players.py app/api/scoring_events.py app/api/game_clock.py app/api/game_lifecycle.py; do
  need "$f" "require_current_user"
done

need app/api/players.py "can_manage_team"
need app/api/players.py "can_view_team"
need app/api/scoring_events.py "can_operate_game"
need app/api/scoring_events.py "can_view_game"
need app/api/game_clock.py "can_operate_game"
need app/api/game_clock.py "can_view_game"
need app/api/game_lifecycle.py "can_operate_game"
need app/api/game_lifecycle.py "can_view_game"
need app/auth/security.py "require_same_origin_mutation"
need app/auth/security.py "AUTH_SESSION_COOKIE_SECURE"
need app/auth/security.py "DB_PASSWORD"
need app/auth/security.py "SOCKET_CORS_ORIGINS"
need app/main.py 'X-Content-Type-Options'
need app/main.py 'Referrer-Policy'
need app/main.py 'X-Frame-Options'
need app/main.py 'pop("test:broadcast", None)'
need app/api/control.py '/api/public/games/{game_id}/overlay-state'
need app/api/team_logos.py 'retrieve_logo'

echo "PASS: M16-C security/tenant hardening source invariants"
