#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0

check(){
  local d="$1" p="$2" f="$3"
  if grep -Fq "$p" "$f"; then
    echo "PASS $d"
  else
    echo "FAIL $d"
    fail=1
  fi
}

if [[ "$VALIDATION_MODE" == "local" ]]; then
  check "Team club scope" 'club_id: Mapped[Optional[uuid.UUID]]' app/models/team.py
  check "Game club scope" 'club_id: Mapped[Optional[uuid.UUID]]' app/models/game.py
  check "TeamManager assignment" 'class TeamManager(Base):' app/models/team_manager.py
  check "GameOperator assignment" 'class GameOperator(Base):' app/models/game_operator.py
  check "team authorization" 'async def can_manage_team(' app/auth/authorization.py
  check "game authorization" 'async def can_operate_game(' app/auth/authorization.py
  check "game create event preserved" 'await sio.emit("game:created", _serialize_game(game))' app/services/game_service.py
  check "team create event preserved" 'await sio.emit("team:created", _serialize_team(team))' app/services/team_service.py
  check "Game API authenticated" 'current_user: User = Depends(require_current_user)' app/api/games.py
  check "Team API authenticated" 'current_user: User = Depends(require_current_user)' app/api/teams.py
  check "Game list Club scoped" 'club_id=_require_club(current_user)' app/api/games.py
  check "Team list Club scoped" 'list_teams(db, _require_club(current_user))' app/api/teams.py
  check "protected Control Center" 'current_user: User = Depends(require_current_user)' app/api/control.py
  check "public Overlay state API" '"/api/public/games/{game_id}/overlay-state"' app/api/control.py
  check "Overlay uses public snapshot" 'api(`/api/public/games/${gameId}/overlay-state`)' static/js/overlay/overlay.js

  if grep -Fq '"club_id"' app/api/control.py; then
    echo "FAIL public Overlay response exposes club_id"
    fail=1
  else
    echo "PASS public Overlay response omits club_id"
  fi
fi

for path in "/api/games" "/api/teams"; do
  status="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}${path}" || true)"
  if [[ "$status" == "401" ]]; then
    echo "PASS unauthenticated ${path} rejected"
  else
    echo "FAIL unauthenticated ${path} expected 401 got ${status}"
    fail=1
  fi
done

control_status="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}/control/games/00000000-0000-0000-0000-000000000000" || true)"
[[ "$control_status" == "401" ]] && echo "PASS unauthenticated Control Center rejected" || { echo "FAIL Control Center expected 401 got ${control_status}"; fail=1; }

overlay_status="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}/overlay/games/00000000-0000-0000-0000-000000000000" || true)"
[[ "$overlay_status" == "200" ]] && echo "PASS public Overlay shell preserved" || { echo "FAIL public Overlay shell expected 200 got ${overlay_status}"; fail=1; }

public_state_status="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}/api/public/games/00000000-0000-0000-0000-000000000000/overlay-state" || true)"
[[ "$public_state_status" == "404" ]] && echo "PASS public Overlay state bypasses authentication" || { echo "FAIL public Overlay state expected 404 for fake Game, got ${public_state_status}"; fail=1; }

exit "$fail"
