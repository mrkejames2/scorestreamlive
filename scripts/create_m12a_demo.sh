#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"

post(){
  curl -fsS \
    -X POST "$1" \
    -H "Content-Type: application/json" \
    -d "$2"
}

field(){
  python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"
}

HOME=$(post "${BASE_URL}/api/teams" \
  '{"name":"Saginaw United","short_name":"SAG"}')

AWAY=$(post "${BASE_URL}/api/teams" \
  '{"name":"Midland City","short_name":"MID"}')

HOME_ID=$(printf '%s' "$HOME" | field id)
AWAY_ID=$(printf '%s' "$AWAY" | field id)

GAME=$(post "${BASE_URL}/api/games" \
  "{\"name\":\"M12-A Game Management Demo\",\"home_team_id\":\"${HOME_ID}\",\"away_team_id\":\"${AWAY_ID}\"}")

GAME_ID=$(printf '%s' "$GAME" | field id)

post "${BASE_URL}/api/games/${GAME_ID}/lifecycle" '{}' >/dev/null
post "${BASE_URL}/api/games/${GAME_ID}/clock" \
  '{"mode":"count_up","duration_seconds":2700}' >/dev/null

echo "========================================"
echo "ScoreStreamLive M12-A Game Management Demo"
echo "========================================"
echo ""
echo "GAME MANAGEMENT"
echo "${BASE_URL}/games"
echo ""
echo "CREATED GAME"
echo "${GAME_ID}"
echo ""
echo "EXPECTED"
echo "- M12-A demo game appears in /games"
echo "- Saginaw United vs Midland City is visible"
echo "- Score is 0 — 0"
echo "- Phase is Pregame"
echo "- Clock is Stopped"
echo "- Open Control Center launches the existing controller"
echo "- Open Overlay launches the existing broadcast overlay"
echo "========================================"
