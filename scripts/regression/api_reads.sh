#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0

for path in "/api/games" "/api/teams"; do
  code="$(curl -sS -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)"
  if [[ "$code" == "401" ]]; then
    echo "PASS HTTP ${path} requires authentication -> 401"
  else
    echo "FAIL HTTP ${path} expected 401, got ${code}"
    fail=1
  fi
done

if [[ "$VALIDATION_MODE" == "local" ]]; then
  grep -Fq 'current_user: User = Depends(require_current_user)' app/api/games.py || {
    echo "FAIL Game collection authentication dependency missing"
    fail=1
  }

  grep -Fq 'current_user: User = Depends(require_current_user)' app/api/teams.py || {
    echo "FAIL Team collection authentication dependency missing"
    fail=1
  }

  grep -Fq 'club_id=_require_club(current_user)' app/api/games.py \
    || grep -Fq 'club_id=_require_club(' app/api/games.py \
    || grep -Fq '_require_club(current_user)' app/api/games.py || {
      echo "FAIL Game collection Club scoping missing"
      fail=1
    }

  grep -Fq '_require_club(current_user)' app/api/teams.py || {
    echo "FAIL Team collection Club scoping missing"
    fail=1
  }

  grep -Fq 'visible_game_ids(db, current_user)' app/api/games.py || {
    echo "FAIL Game role visibility filtering missing"
    fail=1
  }

  grep -Fq 'visible_team_ids(' app/api/teams.py || {
    echo "FAIL Team role visibility filtering missing"
    fail=1
  }
fi

exit "$fail"
