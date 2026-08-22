#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

check_code() {
  local path="$1"
  local expected="$2"
  local label="$3"
  local code
  code="$(curl -sS -o "$tmp" -w "%{http_code}" "${BASE_URL}${path}" || true)"
  if [[ "$code" == "$expected" ]]; then
    echo "PASS $label -> HTTP $code"
  else
    echo "FAIL $label -> HTTP $code expected $expected"
    fail=1
  fi
}

check_code "/api/games" 200 "unbounded Game list"
check_code "/api/games?limit=1" 200 "bounded Game list limit=1"

python3 - "$tmp" <<'PY' || fail=1
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
if not isinstance(data, list):
    raise SystemExit("FAIL limit=1 did not return a JSON list")
if len(data) > 1:
    raise SystemExit(f"FAIL limit=1 returned {len(data)} Games")
print(f"PASS limit=1 returned {len(data)} Game(s)")
if data:
    if "home_team" not in data[0] or "away_team" not in data[0]:
        raise SystemExit("FAIL embedded Team briefs missing")
    print("PASS embedded Team briefs preserved")
PY

for spec in "/api/games?limit=0:422" "/api/games?limit=101:422" "/api/games?limit=abc:422"; do
  IFS=: read -r path expected <<<"$spec"
  check_code "$path" "$expected" "invalid limit rejected"
done

if [[ "$VALIDATION_MODE" == "local" ]]; then
  grep -Fq 'limit: Optional[int] = Query(' app/api/games.py || { echo "FAIL API Query limit missing"; fail=1; }
  grep -Fq 'return await list_games(db, limit=limit)' app/api/games.py || { echo "FAIL API delegation missing"; fail=1; }
  grep -Fq 'limit: Optional[int] = None' app/services/game_service.py || { echo "FAIL service limit missing"; fail=1; }
  grep -Fq 'func.coalesce(' app/services/game_service.py || { echo "FAIL recency ordering missing"; fail=1; }
  grep -Fq '.limit(limit)' app/services/game_service.py || { echo "FAIL SQL limit missing"; fail=1; }
  grep -Fq '`/api/games?limit=${MAX_VISIBLE_GAMES}`' static/js/games/index.js || { echo "FAIL bounded browser request missing"; fail=1; }
  grep -Fq 'async function ensureTeamsLoaded()' static/js/games/index.js || { echo "FAIL lazy Team loader missing"; fail=1; }
  grep -Fq 'game.home_team' static/js/games/index.js || { echo "FAIL embedded home Team usage missing"; fail=1; }
  grep -Fq 'game.away_team' static/js/games/index.js || { echo "FAIL embedded away Team usage missing"; fail=1; }

  load_block="$(awk '/async function loadGames\(options = \{\}\)/{c=1} c{print} c&&/^}/{exit}' static/js/games/index.js)"
  if grep -Fq 'api("/api/teams")' <<<"$load_block"; then
    echo "FAIL /api/teams still eagerly loaded in loadGames"
    fail=1
  else
    echo "PASS /api/teams not eagerly loaded in loadGames"
  fi
fi

exit "$fail"
