#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $1"; }
bad(){ echo "FAIL $1"; fail=1; }
need_file(){ [[ -f "$1" ]] && pass "$1 present" || bad "$1 missing"; }
need_text(){ grep -Fq "$2" "$1" && pass "$3" || bad "$3"; }

for file in \
  app/api/public_summary.py \
  app/services/public_game_summary_service.py \
  templates/summary/game.html \
  templates/broadcast/game.html \
  static/js/public-game-summary.js \
  static/css/game-summary.css \
  static/css/broadcast-summary.css
do
  need_file "$file"
done

need_text app/main.py \
  'from app.api.public_summary import router as public_summary_router' \
  'public summary router imported'
need_text app/main.py \
  'app.include_router(public_summary_router)' \
  'public summary router registered'
need_text app/api/public_summary.py \
  '/api/public/games/{game_id}/summary' \
  'public summary API route declared'
need_text app/api/public_summary.py \
  '/summary/games/{game_id}' \
  'public summary page route declared'
need_text app/api/public_summary.py \
  '/broadcast/games/{game_id}' \
  'broadcast scene route declared'
need_text static/js/public-game-summary.js \
  'audience: "overlay"' \
  'public socket audience used'
need_text app/services/public_game_summary_service.py \
  'ScoringEvent.game_elapsed_seconds.asc().nulls_last()' \
  'match chronology ordering is authoritative'
need_text app/services/public_game_summary_service.py \
  '"is_final": phase == "full_time"' \
  'FINAL derives from lifecycle full_time'
need_text app/services/public_game_summary_service.py \
  '"Unknown scorer"' \
  'unknown scorer presentation defined'

# Public API/page must not depend on authenticated-user dependencies.
if grep -Eq 'require_current_user|can_view_game|can_operate_game' app/api/public_summary.py; then
  bad 'public summary routes unexpectedly reference private authorization dependencies'
else
  pass 'public summary routes remain unauthenticated/read-only'
fi

# Public projection must not expose known private administrative fields.
if grep -Eq '"(club_id|request_id|user_id|role|game_operator|team_manager)"[[:space:]]*:' app/services/public_game_summary_service.py; then
  bad 'public projection exposes a private administrative field'
else
  pass 'public projection excludes private administrative fields'
fi

# Safe runtime checks: random Game must return 404 and require no mutation.
if [[ -n "${BASE_URL:-}" ]]; then
  RANDOM_GAME="00000000-0000-0000-0000-000000000017"
  for path in \
    "/api/public/games/$RANDOM_GAME/summary" \
    "/summary/games/$RANDOM_GAME" \
    "/broadcast/games/$RANDOM_GAME"
  do
    code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL$path" || true)"
    [[ "$code" == "404" ]] && pass "$path masks unavailable Game as 404" || bad "$path expected 404, got $code"
  done
fi

exit "$fail"
