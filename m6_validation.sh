#!/usr/bin/env bash
# ScoreStreamLive — Milestone 6 Validation Script (v2)
# Run while: docker compose up --build
# Requires: curl, jq

set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost:8000}"
PASS=0
FAIL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Temporary files
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

#######################################
# Helpers
#######################################

http_code() {
    cat "$1.status"
}

body() {
    cat "$1.body"
}

assert_status() {
    local test_name="$1"
    local file="$2"
    local expected="$3"
    local actual
    actual=$(http_code "$file")
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC} — $test_name (status $actual)"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC} — $test_name (expected $expected, got $actual)"
        echo "Response: $(body "$file" | head -c 500)"
        ((FAIL++))
    fi
}

assert_json_field() {
    local test_name="$1"
    local file="$2"
    local jq_path="$3"
    local expected="$4"
    local actual
    actual=$(body "$file" | jq -r "$jq_path" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC} — $test_name ($jq_path = $expected)"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC} — $test_name ($jq_path expected '$expected', got '$actual')"
        ((FAIL++))
    fi
}

assert_json_not_empty() {
    local test_name="$1"
    local file="$2"
    local jq_path="$3"
    local actual
    actual=$(body "$file" | jq -r "$jq_path" 2>/dev/null)
    if [[ -n "$actual" && "$actual" != "null" ]]; then
        echo -e "${GREEN}PASS${NC} — $test_name ($jq_path present)"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC} — $test_name ($jq_path missing or null)"
        ((FAIL++))
    fi
}

assert_json_array_length() {
    local test_name="$1"
    local file="$2"
    local jq_path="$3"
    local expected="$4"
    local actual
    actual=$(body "$file" | jq -r "$jq_path | length" 2>/dev/null)
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}PASS${NC} — $test_name (array length = $expected)"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC} — $test_name (expected length $expected, got $actual)"
        ((FAIL++))
    fi
}

assert_json_array_min_length() {
    local test_name="$1"
    local file="$2"
    local jq_path="$3"
    local min="$4"
    local actual
    actual=$(body "$file" | jq -r "$jq_path | length" 2>/dev/null)
    if [[ "$actual" -ge "$min" ]]; then
        echo -e "${GREEN}PASS${NC} — $test_name (array length $actual >= $min)"
        ((PASS++))
    else
        echo -e "${RED}FAIL${NC} — $test_name (expected length >= $min, got $actual)"
        ((FAIL++))
    fi
}

request() {
    local method="$1"
    local url="$2"
    local payload="${3:-}"
    local outfile="$4"
    if [[ -n "$payload" ]]; then
        curl -s -o "${outfile}.body" -w "%{http_code}" \
            -X "$method" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$url" > "${outfile}.status"
    else
        curl -s -o "${outfile}.body" -w "%{http_code}" \
            -X "$method" \
            "$url" > "${outfile}.status"
    fi
}

#######################################
# M0–M1 Health Checks
#######################################

echo -e "\n${YELLOW}=== M0–M1 Health Checks ===${NC}"

request GET "$BASE_URL/" "" "$TMPDIR/root"
assert_status "GET /" "$TMPDIR/root" "200"
assert_json_field "Root status" "$TMPDIR/root" ".status" "running"

request GET "$BASE_URL/health/live" "" "$TMPDIR/live"
assert_status "GET /health/live" "$TMPDIR/live" "200"
assert_json_field "Live status" "$TMPDIR/live" ".status" "ok"

request GET "$BASE_URL/health/ready" "" "$TMPDIR/ready"
assert_status "GET /health/ready" "$TMPDIR/ready" "200"
assert_json_field "Ready status" "$TMPDIR/ready" ".status" "ready"

request GET "$BASE_URL/info" "" "$TMPDIR/info"
assert_status "GET /info" "$TMPDIR/info" "200"
assert_json_not_empty "Info application" "$TMPDIR/info" ".application"

#######################################
# M5 — Create Prerequisite Teams
#######################################

echo -e "\n${YELLOW}=== M5 — Create Prerequisite Teams ===${NC}"

request POST "$BASE_URL/api/teams" \
    '{"name": "Milestone Six FC", "short_name": "M6FC"}' \
    "$TMPDIR/team_a"
assert_status "Create Team A" "$TMPDIR/team_a" "201"
TEAM_A_ID=$(body "$TMPDIR/team_a" | jq -r '.id')
echo "  → Team A ID: $TEAM_A_ID"

request POST "$BASE_URL/api/teams" \
    '{"name": "Opposition United", "short_name": "OU"}' \
    "$TMPDIR/team_b"
assert_status "Create Team B" "$TMPDIR/team_b" "201"
TEAM_B_ID=$(body "$TMPDIR/team_b" | jq -r '.id')
echo "  → Team B ID: $TEAM_B_ID"

#######################################
# M6 — Player Create
#######################################

echo -e "\n${YELLOW}=== M6 — Player Create ===${NC}"

request POST "$BASE_URL/api/players" \
    "{\"team_id\":\"$TEAM_A_ID\",\"first_name\":\"Milestone\",\"last_name\":\"Six\",\"jersey_number\":10}" \
    "$TMPDIR/player_create"
assert_status "Create Player" "$TMPDIR/player_create" "201"
assert_json_field "Player first_name" "$TMPDIR/player_create" ".first_name" "Milestone"
assert_json_field "Player last_name" "$TMPDIR/player_create" ".last_name" "Six"
assert_json_field "Player jersey_number" "$TMPDIR/player_create" ".jersey_number" "10"
assert_json_field "Player team_id" "$TMPDIR/player_create" ".team_id" "$TEAM_A_ID"
assert_json_not_empty "Player id" "$TMPDIR/player_create" ".id"
assert_json_not_empty "Player created_at" "$TMPDIR/player_create" ".created_at"
assert_json_not_empty "Player updated_at" "$TMPDIR/player_create" ".updated_at"

PLAYER_ID=$(body "$TMPDIR/player_create" | jq -r '.id')
echo "  → Player ID: $PLAYER_ID"

#######################################
# M6 — Player Get
#######################################

echo -e "\n${YELLOW}=== M6 — Player Get ===${NC}"

request GET "$BASE_URL/api/players/$PLAYER_ID" "" "$TMPDIR/player_get"
assert_status "Get Player" "$TMPDIR/player_get" "200"
assert_json_field "Get first_name" "$TMPDIR/player_get" ".first_name" "Milestone"
assert_json_field "Get team_id" "$TMPDIR/player_get" ".team_id" "$TEAM_A_ID"

#######################################
# M6 — Player Update
#######################################

echo -e "\n${YELLOW}=== M6 — Player Update ===${NC}"

request PATCH "$BASE_URL/api/players/$PLAYER_ID" \
    '{"jersey_number": 11}' \
    "$TMPDIR/player_update"
assert_status "Update Player jersey" "$TMPDIR/player_update" "200"
assert_json_field "Updated jersey_number" "$TMPDIR/player_update" ".jersey_number" "11"
assert_json_field "Team unchanged" "$TMPDIR/player_update" ".team_id" "$TEAM_A_ID"

# Verify updated_at changed
OLD_UPDATED=$(body "$TMPDIR/player_create" | jq -r '.updated_at')
NEW_UPDATED=$(body "$TMPDIR/player_update" | jq -r '.updated_at')
if [[ "$OLD_UPDATED" != "$NEW_UPDATED" ]]; then
    echo -e "${GREEN}PASS${NC} — updated_at changed after PATCH"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC} — updated_at did not change after PATCH"
    ((FAIL++))
fi

#######################################
# M6 — Team Roster
#######################################

echo -e "\n${YELLOW}=== M6 — Team Roster ===${NC}"

request GET "$BASE_URL/api/teams/$TEAM_A_ID/players" "" "$TMPDIR/roster_a"
assert_status "Get Team A roster" "$TMPDIR/roster_a" "200"
assert_json_array_length "Roster contains player" "$TMPDIR/roster_a" "." "1"
assert_json_field "Roster player id" "$TMPDIR/roster_a" ".[0].id" "$PLAYER_ID"

#######################################
# M6 — Team Isolation
#######################################

echo -e "\n${YELLOW}=== M6 — Team Isolation ===${NC}"

request GET "$BASE_URL/api/teams/$TEAM_B_ID/players" "" "$TMPDIR/roster_b"
assert_status "Get Team B roster" "$TMPDIR/roster_b" "200"
assert_json_array_length "Team B roster empty" "$TMPDIR/roster_b" "." "0"

#######################################
# M6 — Roster Ordering
#######################################

echo -e "\n${YELLOW}=== M6 — Roster Ordering ===${NC}"

# Create players with specific ordering characteristics
request POST "$BASE_URL/api/players" \
    "{\"team_id\":\"$TEAM_A_ID\",\"first_name\":\"Alpha\",\"last_name\":\"Zebra\",\"jersey_number\":5}" \
    "$TMPDIR/order_1"
assert_status "Create ordering player 1" "$TMPDIR/order_1" "201"

request POST "$BASE_URL/api/players" \
    "{\"team_id\":\"$TEAM_A_ID\",\"first_name\":\"Beta\",\"last_name\":\"Apple\",\"jersey_number\":5}" \
    "$TMPDIR/order_2"
assert_status "Create ordering player 2" "$TMPDIR/order_2" "201"

request POST "$BASE_URL/api/players" \
    "{\"team_id\":\"$TEAM_A_ID\",\"first_name\":\"No\",\"last_name\":\"Number\",\"jersey_number\":null}" \
    "$TMPDIR/order_3"
assert_status "Create ordering player 3 (no jersey)" "$TMPDIR/order_3" "201"

request GET "$BASE_URL/api/teams/$TEAM_A_ID/players" "" "$TMPDIR/roster_ordered"
assert_status "Get ordered roster" "$TMPDIR/roster_ordered" "200"
assert_json_array_length "Ordered roster length" "$TMPDIR/roster_ordered" "." "4"

# Verify ordering: jersey 5s first, Apple before Zebra, no-jersey last
JN0=$(body "$TMPDIR/roster_ordered" | jq -r '.[0].jersey_number // "null"')
LN0=$(body "$TMPDIR/roster_ordered" | jq -r '.[0].last_name')
JN1=$(body "$TMPDIR/roster_ordered" | jq -r '.[1].jersey_number // "null"')
LN1=$(body "$TMPDIR/roster_ordered" | jq -r '.[1].last_name')
JN3=$(body "$TMPDIR/roster_ordered" | jq -r '.[3].jersey_number // "null"')
LN3=$(body "$TMPDIR/roster_ordered" | jq -r '.[3].last_name')

ORDER_OK=true
if [[ "$JN0" != "5" || "$LN0" != "Apple" ]]; then
    ORDER_OK=false
    echo -e "${RED}FAIL${NC} — Roster ordering position 0 (expected jersey=5, last_name=Apple, got jersey=$JN0, last_name=$LN0)"
    ((FAIL++))
fi
if [[ "$JN1" != "5" || "$LN1" != "Zebra" ]]; then
    ORDER_OK=false
    echo -e "${RED}FAIL${NC} — Roster ordering position 1 (expected jersey=5, last_name=Zebra, got jersey=$JN1, last_name=$LN1)"
    ((FAIL++))
fi
if [[ "$JN3" != "null" || "$LN3" != "Number" ]]; then
    ORDER_OK=false
    echo -e "${RED}FAIL${NC} — Roster ordering position 3 (expected jersey=null, last_name=Number, got jersey=$JN3, last_name=$LN3)"
    ((FAIL++))
fi
if $ORDER_OK; then
    echo -e "${GREEN}PASS${NC} — Roster ordering correct (jersey ASC NULLS LAST, last_name, first_name, id)"
    ((PASS++))
fi

#######################################
# M6 — Error Cases
#######################################

echo -e "\n${YELLOW}=== M6 — Error Cases ===${NC}"

# Invalid team_id
request POST "$BASE_URL/api/players" \
    '{"team_id":"00000000-0000-0000-0000-000000000000","first_name":"Ghost","last_name":"Player","jersey_number":1}' \
    "$TMPDIR/err_team"
assert_status "Invalid team_id returns 422" "$TMPDIR/err_team" "422"

# Blank first_name
request POST "$BASE_URL/api/players" \
    "{\"team_id\":\"$TEAM_A_ID\",\"first_name\":\"   \",\"last_name\":\"Test\",\"jersey_number\":1}" \
    "$TMPDIR/err_blank"
assert_status "Blank first_name returns 422" "$TMPDIR/err_blank" "422"

# Invalid jersey number
request POST "$BASE_URL/api/players" \
    "{\"team_id\":\"$TEAM_A_ID\",\"first_name\":\"Bad\",\"last_name\":\"Number\",\"jersey_number\":1000}" \
    "$TMPDIR/err_jersey"
assert_status "Jersey 1000 returns 422" "$TMPDIR/err_jersey" "422"

# Missing player
request GET "$BASE_URL/api/players/00000000-0000-0000-0000-000000000000" "" "$TMPDIR/err_missing_player"
assert_status "Missing player returns 404" "$TMPDIR/err_missing_player" "404"

# Missing team for roster
request GET "$BASE_URL/api/teams/00000000-0000-0000-0000-000000000000/players" "" "$TMPDIR/err_missing_team_roster"
assert_status "Missing team roster returns 404" "$TMPDIR/err_missing_team_roster" "404"

# PATCH empty last_name
request PATCH "$BASE_URL/api/players/$PLAYER_ID" \
    '{"last_name": ""}' \
    "$TMPDIR/err_patch_empty"
assert_status "PATCH empty last_name returns 422" "$TMPDIR/err_patch_empty" "422"

# PATCH team_id — Pydantic v2 ignores extra fields by default (matching existing Game/Team convention)
# team_id is NOT mutated; request succeeds as a no-op for that field
request PATCH "$BASE_URL/api/players/$PLAYER_ID" \
    "{\"team_id\":\"$TEAM_B_ID\"}" \
    "$TMPDIR/patch_team_id"
assert_status "PATCH team_id returns 200 (extra field ignored)" "$TMPDIR/patch_team_id" "200"
assert_json_field "PATCH team_id unchanged" "$TMPDIR/patch_team_id" ".team_id" "$TEAM_A_ID"

#######################################
# M4–M5 Regression
#######################################

echo -e "\n${YELLOW}=== M4–M5 Regression ===${NC}"

# List teams (may have pre-existing data; just verify our created teams exist)
request GET "$BASE_URL/api/teams" "" "$TMPDIR/reg_teams"
assert_status "List teams" "$TMPDIR/reg_teams" "200"
assert_json_array_min_length "Teams list has our teams" "$TMPDIR/reg_teams" "." "2"

# Verify Team A exists in list
TEAM_A_IN_LIST=$(body "$TMPDIR/reg_teams" | jq --arg id "$TEAM_A_ID" 'map(.id) | contains([$id])')
if [[ "$TEAM_A_IN_LIST" == "true" ]]; then
    echo -e "${GREEN}PASS${NC} — Team A present in list"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC} — Team A missing from list"
    ((FAIL++))
fi

# Update team
request PATCH "$BASE_URL/api/teams/$TEAM_A_ID" \
    '{"short_name": "M6X"}' \
    "$TMPDIR/reg_team_update"
assert_status "Update team" "$TMPDIR/reg_team_update" "200"
assert_json_field "Team short_name updated" "$TMPDIR/reg_team_update" ".short_name" "M6X"

# Create game
request POST "$BASE_URL/api/games" \
    "{\"name\":\"Regression Test Match\",\"status\":\"scheduled\",\"home_team_id\":\"$TEAM_A_ID\",\"away_team_id\":\"$TEAM_B_ID\"}" \
    "$TMPDIR/reg_game"
assert_status "Create game" "$TMPDIR/reg_game" "201"
assert_json_not_empty "Game id" "$TMPDIR/reg_game" ".id"
assert_json_field "Game home_team_id" "$TMPDIR/reg_game" ".home_team_id" "$TEAM_A_ID"
assert_json_field "Game away_team_id" "$TMPDIR/reg_game" ".away_team_id" "$TEAM_B_ID"

GAME_ID=$(body "$TMPDIR/reg_game" | jq -r '.id')

# Get game
request GET "$BASE_URL/api/games/$GAME_ID" "" "$TMPDIR/reg_game_get"
assert_status "Get game" "$TMPDIR/reg_game_get" "200"
assert_json_field "Get game name" "$TMPDIR/reg_game_get" ".name" "Regression Test Match"

# List games
request GET "$BASE_URL/api/games" "" "$TMPDIR/reg_games_list"
assert_status "List games" "$TMPDIR/reg_games_list" "200"

#######################################
# Summary
#######################################

echo -e "\n${YELLOW}========================================${NC}"
echo -e "${YELLOW}  MILESTONE 6 VALIDATION SUMMARY${NC}"
echo -e "${YELLOW}========================================${NC}"
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All tests passed. Milestone 6 is ready for Devin deployment.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ $FAIL test(s) failed. Review output above before proceeding.${NC}"
    exit 1
fi
