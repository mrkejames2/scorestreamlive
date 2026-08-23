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

check_unauthenticated "/api/games" "unbounded Game list"
check_unauthenticated "/api/games?limit=1" "bounded Game list"
check_unauthenticated "/api/games?limit=0" "invalid limit hidden behind auth"
check_unauthenticated "/api/games?limit=101" "invalid limit hidden behind auth"
check_unauthenticated "/api/games?limit=abc" "invalid limit hidden behind auth"

if [[ "$VALIDATION_MODE" == "local" ]]; then
  grep -Fq 'limit: Optional[int] = Query(' app/api/games.py || {
    echo "FAIL API Query limit missing"
    fail=1
  }

  grep -Fq 'games = await list_games(' app/api/games.py || {
    echo "FAIL authenticated Game service delegation missing"
    fail=1
  }

  grep -Fq '_require_club(current_user)' app/api/games.py || {
    echo "FAIL authenticated Club-scoped Game delegation missing"
    fail=1
  }

  grep -Fq 'visible_game_ids(db, current_user)' app/api/games.py || {
    echo "FAIL role-filtered Game delegation missing"
    fail=1
  }

  grep -Fq 'limit=None' app/api/games.py \
    || grep -Fq 'limit=None,' app/api/games.py || {
      echo "FAIL service retrieval-before-role-filter pattern missing"
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
    echo "FAIL SQL limit support missing"
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

  load_block="$(
    awk '
      /async function loadGames\(options = \{\}\)/ { c=1 }
      c { print }
      c && /^}/ { exit }
    ' static/js/games/index.js
  )"

  if grep -Fq 'api("/api/teams")' <<<"$load_block"; then
    echo "FAIL /api/teams still eagerly loaded in loadGames"
    fail=1
  else
    echo "PASS /api/teams not eagerly loaded in loadGames"
  fi
fi

exit "$fail"
