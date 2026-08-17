#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://localhost:8000}"
STAMP="$(date +%s)"

post(){ curl -fsS -X POST "$1" -H "Content-Type: application/json" -d "$2"; }
field(){ python3 -c "import json,sys; print(json.load(sys.stdin)['$1'])"; }

echo "========================================"
echo "ScoreStreamLive M10-H Final Demo Creator"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

HOME=$(post "${BASE_URL}/api/teams" "{\"name\":\"Saginaw United M10H ${STAMP}\",\"short_name\":\"SAG\"}")
AWAY=$(post "${BASE_URL}/api/teams" "{\"name\":\"Midland City M10H ${STAMP}\",\"short_name\":\"MID\"}")
HOME_ID=$(printf '%s' "$HOME"|field id)
AWAY_ID=$(printf '%s' "$AWAY"|field id)

GAME=$(post "${BASE_URL}/api/games" "{\"name\":\"M10-H Final Acceptance Match ${STAMP}\",\"home_team_id\":\"${HOME_ID}\",\"away_team_id\":\"${AWAY_ID}\"}")
GAME_ID=$(printf '%s' "$GAME"|field id)

post "${BASE_URL}/api/games/${GAME_ID}/lifecycle" '{}' >/dev/null
post "${BASE_URL}/api/games/${GAME_ID}/clock" '{"mode":"count_up","duration_seconds":2700}' >/dev/null

player(){
 post "${BASE_URL}/api/players" "{\"team_id\":\"$1\",\"first_name\":\"$2\",\"last_name\":\"$3\",\"jersey_number\":\"$4\"}" >/dev/null
}
player "$HOME_ID" Ace James 7
player "$HOME_ID" Maverick James 10
player "$HOME_ID" Wyatt James 11
player "$AWAY_ID" Alex Morgan 9
player "$AWAY_ID" Jordan Taylor 12
player "$AWAY_ID" Casey Parker 18

echo ""
echo "DEMO CREATED"
echo "Game ID: ${GAME_ID}"
echo "Control Center:"
echo "${BASE_URL}/control/games/${GAME_ID}"
echo ""
echo "Open this SAME URL on at least two devices."
