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
  "{\"name\":\"M11-G Final Broadcast Acceptance\",\"home_team_id\":\"${HOME_ID}\",\"away_team_id\":\"${AWAY_ID}\"}")

GAME_ID=$(printf '%s' "$GAME" | field id)

post "${BASE_URL}/api/games/${GAME_ID}/lifecycle" '{}' >/dev/null
post "${BASE_URL}/api/games/${GAME_ID}/clock" \
  '{"mode":"count_up","duration_seconds":2700}' >/dev/null

for player in \
  "Maverick|James|10" \
  "Wyatt|James|7" \
  "Ace|James|9"
do
  IFS='|' read -r FIRST LAST JERSEY <<< "$player"
  post "${BASE_URL}/api/players" \
    "{\"team_id\":\"${HOME_ID}\",\"first_name\":\"${FIRST}\",\"last_name\":\"${LAST}\",\"jersey_number\":${JERSEY}}" \
    >/dev/null
done

echo "========================================"
echo "ScoreStreamLive M11-G Final Broadcast Acceptance"
echo "========================================"
echo ""
echo "Game ID:"
echo "${GAME_ID}"
echo ""
echo "CONTROL CENTER"
echo "${BASE_URL}/control/games/${GAME_ID}"
echo ""
echo "BROADCAST OVERLAY"
echo "${BASE_URL}/overlay/games/${GAME_ID}"
echo ""
echo "FINAL HUMAN TEST"
echo "1. Start First Half"
echo "2. Compare clocks at 30s, 60s, 2m, and 5m"
echo "3. Record a named-player goal"
echo "4. Record a Team Goal / Unknown Scorer"
echo "5. End First Half -> HALFTIME"
echo "6. Start Second Half -> SECOND HALF"
echo "7. Record another goal"
echo "8. End Game -> FULL TIME"
echo "9. Confirm overlay never required a refresh"
echo "10. Confirm Control Center / Overlay clock difference stayed <= 1 second"
echo ""
echo "If all pass: M11-G HUMAN ACCEPTANCE = PASS"
echo "========================================"
