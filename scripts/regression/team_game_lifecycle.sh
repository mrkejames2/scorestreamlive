#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
source scripts/lib/validation.sh; validation_init || exit $?
fail=0
pass(){ echo "PASS $1"; }; bad(){ echo "FAIL $1"; fail=1; }
for spec in "app/models/team.py:archived_at" "app/models/game.py:archived_at" "app/api/teams.py:@router.post(\"/{team_id}/archive\"" "app/api/games.py:@router.post(\"/{game_id}/archive\"" "app/services/resource_lifecycle_service.py:delete(GameOperator)" "app/services/resource_lifecycle_service.py:delete(TeamManager)" "app/services/resource_lifecycle_service.py:ScoringEvent.game_id" "app/services/resource_lifecycle_service.py:Player.team_id"; do
 f="${spec%%:*}"; q="${spec#*:}"; grep -Fq "$q" "$f" && pass "$q" || bad "$q"
done
grep -Fq 'down_revision = "20260902_0013"' alembic/versions/20260904_0014_add_team_game_archived_at.py && pass "migration parent" || bad "migration parent"
for path in "/api/teams?archived=true" "/api/games?archived=true"; do
 code="$(curl --connect-timeout 5 --max-time 15 -sS -o /dev/null -w '%{http_code}' "${BASE_URL}${path}" || true)"
 [[ "$code" == 401 ]] && pass "logged-out $path denied" || bad "logged-out $path expected 401 got $code"
done

# REPAIR3 lifecycle UI and read-only archive enforcement.
for file in static/js/m17b-lifecycle.js static/css/m17b-lifecycle.css; do
  [[ -f "$file" ]] && echo "PASS lifecycle UI file $file" || { echo "FAIL missing lifecycle UI file $file"; fail=1; }
done

for template in templates/teams/index.html templates/games/index.html; do
  grep -Fq '/static/js/m17b-lifecycle.js' "$template"     && echo "PASS lifecycle module loaded by $template"     || { echo "FAIL lifecycle module missing from $template"; fail=1; }
done

grep -Fq '?archived=true' static/js/m17b-lifecycle.js   && echo "PASS archived view uses lifecycle API filter"   || { echo "FAIL archived lifecycle filter missing"; fail=1; }

grep -Fq 'Archived Teams are read-only' app/api/players.py   && echo "PASS archived Team roster mutation blocked"   || { echo "FAIL archived Team roster mutation guard missing"; fail=1; }

grep -Fq 'Archived Games are read-only' app/api/game_clock.py   && grep -Fq 'Archived Games are read-only' app/api/game_lifecycle.py   && grep -Fq 'Archived Games are read-only' app/api/scoring_events.py   && echo "PASS archived Game match-day mutation guards present"   || { echo "FAIL archived Game mutation guard missing"; fail=1; }

grep -Fq 'game.archived_at is not None' app/api/control.py   && echo "PASS archived Game Control Center blocked"   || { echo "FAIL archived Game Control Center guard missing"; fail=1; }


# REPAIR3A lifecycle guard ordering and UI follow-up.
[[ "$(grep -Fc 'detail="Archived Games are read-only"' app/api/games.py)" -ge 2 ]]   && echo "PASS ordinary Game mutations reject archived Games"   || { echo "FAIL archived Game ordinary mutation guards missing"; fail=1; }

[[ "$(grep -Fc 'detail="Archived Teams are read-only"' app/api/teams.py)" -ge 2 ]]   && echo "PASS Team update/logo routes reject archived Teams"   || { echo "FAIL archived Team API mutation guards missing"; fail=1; }

grep -Fq 'const active = qs("#teams-list");' static/js/m17b-lifecycle.js   && echo "PASS Teams lifecycle toggle preserves controls"   || { echo "FAIL Teams lifecycle toggle container unsafe"; fail=1; }

exit "$fail"
