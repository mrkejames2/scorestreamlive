#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?

fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

code="$(curl -sS -o "$tmp" -w "%{http_code}" "${BASE_URL}/games" || true)"
[[ "$code" == "200" ]] && echo "PASS /games HTTP 200" || { echo "FAIL /games HTTP ${code}"; fail=1; }

for marker in   'id="summary-total"'   'id="summary-upcoming"'   'id="summary-live"'   'id="summary-completed"'   'id="games-live-list"'   'id="games-upcoming-list"'   'id="games-completed-list"'   'id="games-cancelled-list"'   '>Live Games<'   '>Upcoming<'   '>Completed<'   '/static/css/games-m14b.css'
do
  grep -Fq "$marker" "$tmp"     && echo "PASS dashboard surface: $marker"     || { echo "FAIL dashboard surface missing: $marker"; fail=1; }
done

if [[ "$VALIDATION_MODE" == "local" ]]; then
  for marker in     'function groupByLibraryClassification'     'function renderLibrary(allGames, visibleItems)'     'GameLibraryClassification.LIVE'     'GameLibraryClassification.UPCOMING'     'GameLibraryClassification.COMPLETED'     'GameLibraryClassification.CANCELLED'     'renderLibrary(games, usable);'     'els.liveList'     'els.upcomingList'     'els.completedList'     'els.cancelledList'     '"Review Game"'     '"Resume Game"'     '"Open Game"'     '/games/${game.id}/setup'     '/control/games/${game.id}'     '/overlay/games/${game.id}'
  do
    grep -Fq "$marker" static/js/games/index.js       && echo "PASS dashboard integration: $marker"       || { echo "FAIL dashboard integration missing: $marker"; fail=1; }
  done

  if find alembic/versions -maxdepth 1 -type f \( -iname '*m14*' -o -iname '*0014*' \) | grep -q .; then
    echo "FAIL unexpected M14 migration"
    fail=1
  else
    echo "PASS no M14 migration"
  fi
fi

exit "$fail"
