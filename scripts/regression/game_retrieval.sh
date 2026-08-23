#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0

check_unauthenticated() {
  local path="$1"
  local label="$2"
  local code
  code="$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)"
  if [[ "$code" == "401" ]]; then
    echo "PASS $label requires authentication -> HTTP 401"
  else
    echo "FAIL $label -> HTTP $code expected 401"
    fail=1
  fi
}

# M15-C changed /api/games into an authenticated administrative collection.
# Query validation happens behind the auth boundary, so an unauthenticated
# caller receives 401 before it can observe list/limit behavior.
check_unauthenticated "/api/games" "unbounded Game list"
check_unauthenticated "/api/games?limit=1" "bounded Game list"
check_unauthenticated "/api/games?limit=0" "invalid limit hidden behind auth"
check_unauthenticated "/api/games?limit=101" "invalid limit hidden behind auth"
check_unauthenticated "/api/games?limit=abc" "invalid limit hidden behind auth"

if [[ "$VALIDATION_MODE" == "local" ]]; then
  # Preserve the previously validated retrieval contract structurally while
  # also proving the new Club-scoped delegation.
  grep -Fq 'limit: Optional[int] = Query(' app/api/games.py || {
    echo "FAIL API Query limit missing"
    fail=1
  }
  grep -Fq 'return await list_games(db, limit=limit, club_id=_require_club(current_user))' app/api/games.py || {
    echo "FAIL authenticated Club-scoped API delegation missing"
    fail=1
  }
  grep -Fq 'limit: Optional[int] = None' app/services/game_service.py || {
    echo "FAIL service limit missing"
    fail=1
  }
  grep -Fq 'club_id: Optional[uuid.UUID] = None' app/services/game_service.py || {
    echo "FAIL service Club scope parameter missing"
    fail=1
  }
  grep -Fq 'func.coalesce(' app/services/game_service.py || {
    echo "FAIL recency ordering missing"
    fail=1
  }
  grep -Fq '.limit(limit)' app/services/game_service.py || {
    echo "FAIL SQL limit missing"
    fail=1
  }
  grep -Fq 'selectinload(Game.home_team)' app/services/game_service.py || {
    echo "FAIL embedded home Team loading missing"
    fail=1
  }
  grep -Fq 'selectinload(Game.away_team)' app/services/game_service.py || {
    echo "FAIL embedded away Team loading missing"
    fail=1
  }
  grep -Fq '`/api/games?limit=${MAX_VISIBLE_GAMES}`' static/js/games/index.js || {
    echo "FAIL bounded browser request missing"
    fail=1
  }
  grep -Fq 'async function ensureTeamsLoaded()' static/js/games/index.js || {
    echo "FAIL lazy Team loader missing"
    fail=1
  }
  grep -Fq 'game.home_team' static/js/games/index.js || {
    echo "FAIL embedded home Team usage missing"
    fail=1
  }
  grep -Fq 'game.away_team' static/js/games/index.js || {
    echo "FAIL embedded away Team usage missing"
    fail=1
  }

  load_block="$(awk '/async function loadGames\(options = \{\}\)/{c=1} c{print} c&&/^}/{exit}' static/js/games/index.js)"
  if grep -Fq 'api("/api/teams")' <<<"$load_block"; then
    echo "FAIL /api/teams still eagerly loaded in loadGames"
    fail=1
  else
    echo "PASS /api/teams not eagerly loaded in loadGames"
  fi
fi

exit "$fail"
