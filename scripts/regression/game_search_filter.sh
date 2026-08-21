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

for marker in \
  'id="game-library-search"' \
  'id="game-library-classification-filter"' \
  'id="game-library-clear-filters"' \
  'id="game-library-results-status"' \
  'id="game-library-no-results"' \
  'value="all"' \
  'value="live"' \
  'value="upcoming"' \
  'value="completed"' \
  'value="cancelled"' \
  '/static/css/games-m14c.css' \
  '/static/js/games/filters.js'
do
  grep -Fq "$marker" "$tmp" \
    && echo "PASS Search/Filter surface: $marker" \
    || { echo "FAIL Search/Filter surface missing: $marker"; fail=1; }
done

if [[ "$VALIDATION_MODE" == "local" ]]; then
  for marker in \
    'game.name' \
    'homeTeam?.name' \
    'homeTeam?.short_name' \
    'awayTeam?.name' \
    'awayTeam?.short_name' \
    'card.dataset.searchText'
  do
    grep -Fq "$marker" static/js/games/index.js \
      && echo "PASS searchable card contract: $marker" \
      || { echo "FAIL searchable card contract missing: $marker"; fail=1; }
  done

  for marker in \
    'function normalizedSearchValue' \
    'function cardMatchesSearch' \
    'function cardMatchesClassification' \
    'function filteredCards' \
    'export function applyGameLibraryFilters' \
    'GameLibraryClassification.LIVE' \
    'GameLibraryClassification.UPCOMING' \
    'GameLibraryClassification.COMPLETED' \
    'GameLibraryClassification.CANCELLED' \
    'Showing ${visible} of ${total} games' \
    'MutationObserver' \
    'clearGameLibraryFilters'
  do
    grep -Fq "$marker" static/js/games/filters.js \
      && echo "PASS Search/Filter behavior: $marker" \
      || { echo "FAIL Search/Filter behavior missing: $marker"; fail=1; }
  done

  if grep -Eq '/api/games\?[^"]*(search|page|filter|status)' static/js/games/index.js static/js/games/filters.js; then
    echo "FAIL server-side Game search/filter query introduced"
    fail=1
  else
    echo "PASS no server-side Game search/filter query"
  fi

  if find alembic/versions -maxdepth 1 -type f \( -iname '*m14*' -o -iname '*0014*' \) | grep -q .; then
    echo "FAIL unexpected M14 database migration"
    fail=1
  else
    echo "PASS no M14 database migration"
  fi
fi

exit "$fail"
