#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8000}"

post(){ curl -fsS -X POST "$1" -H "Content-Type: application/json" -d "$2"; }
field(){ python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }

HOME=$(post "${BASE_URL}/api/teams" '{"name":"Saginaw United","short_name":"SAG"}')
AWAY=$(post "${BASE_URL}/api/teams" '{"name":"Midland City","short_name":"MID"}')
HOME_ID=$(printf '%s' "$HOME"|field id)
AWAY_ID=$(printf '%s' "$AWAY"|field id)

GAME=$(post "${BASE_URL}/api/games" \
  "{\"name\":\"M11-A Broadcast Overlay Demo\",\"home_team_id\":\"${HOME_ID}\",\"away_team_id\":\"${AWAY_ID}\"}")
GAME_ID=$(printf '%s' "$GAME"|field id)

post "${BASE_URL}/api/games/${GAME_ID}/lifecycle" '{}' >/dev/null
post "${BASE_URL}/api/games/${GAME_ID}/clock" \
  '{"mode":"count_up","duration_seconds":2700}' >/dev/null

echo "========================================"
echo "ScoreStreamLive M11-A Demo"
echo "========================================"
echo "Game ID: ${GAME_ID}"
echo ""
echo "CONTROL CENTER"
echo "${BASE_URL}/control/games/${GAME_ID}"
echo ""
echo "BROADCAST OVERLAY"
echo "${BASE_URL}/overlay/games/${GAME_ID}"
echo ""
echo "M11-A is intentionally REST-loaded/read-only."
echo "Refresh the overlay after changing game state in the Control Center."
echo "M11-B will make overlay changes live via Socket.IO."
