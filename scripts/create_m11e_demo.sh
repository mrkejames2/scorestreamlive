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


# ------------------------------------------------------------
# Teams
# ------------------------------------------------------------

HOME=$(
  post \
    "${BASE_URL}/api/teams" \
    '{"name":"Saginaw United","short_name":"SAG"}'
)

AWAY=$(
  post \
    "${BASE_URL}/api/teams" \
    '{"name":"Midland City","short_name":"MID"}'
)

HOME_ID=$(printf '%s' "$HOME" | field id)
AWAY_ID=$(printf '%s' "$AWAY" | field id)


# ------------------------------------------------------------
# Game
# ------------------------------------------------------------

GAME=$(
  post \
    "${BASE_URL}/api/games" \
    "{\"name\":\"M11-E Goal Presentation Demo\",\"home_team_id\":\"${HOME_ID}\",\"away_team_id\":\"${AWAY_ID}\"}"
)

GAME_ID=$(printf '%s' "$GAME" | field id)


# ------------------------------------------------------------
# Lifecycle + clock
# ------------------------------------------------------------

post \
  "${BASE_URL}/api/games/${GAME_ID}/lifecycle" \
  '{}' \
  >/dev/null

post \
  "${BASE_URL}/api/games/${GAME_ID}/clock" \
  '{"mode":"count_up","duration_seconds":2700}' \
  >/dev/null


# ------------------------------------------------------------
# Saginaw United roster
#
# Player creation uses /api/players with team_id in the body.
# ------------------------------------------------------------

post \
  "${BASE_URL}/api/players" \
  "{\"team_id\":\"${HOME_ID}\",\"first_name\":\"Maverick\",\"last_name\":\"James\",\"jersey_number\":10}" \
  >/dev/null

post \
  "${BASE_URL}/api/players" \
  "{\"team_id\":\"${HOME_ID}\",\"first_name\":\"Wyatt\",\"last_name\":\"James\",\"jersey_number\":7}" \
  >/dev/null

post \
  "${BASE_URL}/api/players" \
  "{\"team_id\":\"${HOME_ID}\",\"first_name\":\"Ace\",\"last_name\":\"James\",\"jersey_number\":9}" \
  >/dev/null


echo "========================================"
echo "ScoreStreamLive M11-E Goal Presentation Demo"
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
echo "HOME TEAM"
echo "Saginaw United"
echo ""
echo "HOME ROSTER"
echo "  #10 Maverick James"
echo "  #7  Wyatt James"
echo "  #9  Ace James"
echo ""
echo "TEST:"
echo "1. Open Control Center on your phone."
echo "2. Open Broadcast Overlay on another device."
echo "3. Start First Half."
echo "4. Select a scorer."
echo "5. Record a Saginaw United goal."
echo ""
echo "EXPECTED:"
echo "The overlay score updates immediately and a GOAL banner"
echo "appears automatically for approximately five seconds."
echo "========================================"