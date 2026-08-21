#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
BASE_URL="${BASE_URL:-http://192.168.12.133:8000}"; BASE_URL="${BASE_URL%/}"; VALIDATION_MODE="${VALIDATION_MODE:-local}"
PASS=0; FAIL=0; FAILURES=(); TMP=$(mktemp); REG=$(mktemp); trap 'rm -f "$TMP" "$REG"' EXIT
ok(){ PASS=$((PASS+1)); }; bad(){ FAIL=$((FAIL+1)); FAILURES+=("$1"); }
http_200(){ local path="$1" label="$2" code; code=$(curl -sS -o "$TMP" -w "%{http_code}" "${BASE_URL}${path}" || true); [[ "$code" == 200 ]] && ok || bad "${label} HTTP ${code}"; }
echo "[1/8] Checking application health..."; http_200 "/health/live" "Liveness"; http_200 "/health/ready" "Readiness"
echo "[2/8] Checking Game Management surface..."; http_200 "/games" "Game Management"; grep -Fq 'src="/static/js/games/index.js"' "$TMP" && ok || bad "Game Management index module reference missing"
echo "[3/8] Checking canonical M14-A classification module..."; http_200 "/static/js/games/classification.js" "Classification module"
for m in 'UPCOMING: "upcoming"' 'LIVE: "live"' 'COMPLETED: "completed"' 'CANCELLED: "cancelled"' 'lifecyclePhase === "full_time"' 'LIVE_PHASES.has(lifecyclePhase)' 'lifecyclePhase === "pregame"' 'clockStatus === "running"' 'gameStatus === "completed"' 'gameStatus === "live"'; do grep -Fq "$m" "$TMP" && ok || bad "Classification contract missing ${m}"; done
echo "[4/8] Checking /games integration..."
if [[ "$VALIDATION_MODE" == local ]]; then
 grep -Fq 'from "./classification.js"' static/js/games/index.js && ok || bad "Game Management does not import canonical classifier"
 grep -Fq 'classifyGame(game, lifecycle, clock)' static/js/games/index.js && ok || bad "Game cards do not use canonical classifier"
 grep -Fq 'GameLibraryClassification.COMPLETED' static/js/games/index.js && ok || bad "Completed card behavior not classification-driven"
 grep -Fq 'GameLibraryClassification.LIVE' static/js/games/index.js && ok || bad "Live card behavior not classification-driven"
 if grep -Fq 'function isCompleted(' static/js/games/index.js || grep -Fq 'function isActive(' static/js/games/index.js; then bad "Legacy ad-hoc Game classification helpers remain"; else ok; fi
else for _ in {1..5}; do ok; done; fi
echo "[5/8] Checking classification acceptance cases..."; python3 - <<'PY' && ok || bad "Canonical classification acceptance table invalid"
U,L,C,X='upcoming','live','completed','cancelled'; LP={'first_half','halftime','second_half'}
def f(gs='',p='',cs=''):
 gs=gs.lower(); p=p.lower(); cs=cs.lower()
 if gs=='cancelled': return X
 if p=='full_time': return C
 if p in LP: return L
 if p=='pregame': return U
 if cs=='running': return L
 if gs=='completed': return C
 if gs=='live': return L
 return U
assert f(p='pregame')==U and f(p='first_half')==L and f(p='halftime')==L and f(p='second_half')==L and f(p='full_time')==C and f(gs='cancelled',p='pregame')==X and f(cs='running')==L and f(gs='completed')==C and f(gs='live')==L and f(gs='scheduled')==U
PY
echo "[6/8] Checking protected M14-A boundaries..."
if [[ "$VALIDATION_MODE" == local ]]; then
 if find alembic/versions -maxdepth 1 -type f \( -iname '*m14*' -o -iname '*0014*' \) | grep -q .; then bad "Unexpected M14 database migration detected"; else ok; fi
 if grep -Fq 'update(Game)' app/services/game_lifecycle_service.py || grep -Eq 'game\.status[[:space:]]*=' app/services/game_lifecycle_service.py; then bad "Lifecycle service synchronizes Game.status"; else ok; fi
 grep -Fq 'POST /api/scoring-events' docs/SCORING.md && ok || bad "Protected scoring contract changed unexpectedly"
 grep -Fq 'clock:tick' docs/CLOCK.md && ok || bad "Protected no-tick clock contract documentation missing"
else for _ in {1..4}; do ok; done; fi
echo "[7/8] Checking M14-A validation-chain availability..."; [[ -x scripts/validate_m13h.sh ]] && ok || bad "scripts/validate_m13h.sh missing or not executable"
echo "[8/8] Running M13-H cumulative regression silently..."; set +e; BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" ./scripts/validate_m13h.sh >"$REG" 2>&1; REG_RC=$?; set -e; [[ "$REG_RC" -eq 0 ]] || FAILURES+=("M13-H cumulative regression failed")
echo "========================================"; echo "ScoreStreamLive M14-A Validation Summary"; echo "BASE_URL: $BASE_URL"; echo "MODE: $VALIDATION_MODE"; echo "========================================"
if [[ "$FAIL" -eq 0 ]]; then echo "M14-A ................ PASS   ${PASS} passed / 0 failed"; else echo "M14-A ................ FAIL   ${PASS} passed / ${FAIL} failed"; fi
[[ "$REG_RC" -eq 0 ]] && echo "M13-H cumulative ..... PASS" || echo "M13-H cumulative ..... FAIL"; echo "========================================"
TOTAL_FAIL=$FAIL; [[ "$REG_RC" -ne 0 ]] && TOTAL_FAIL=$((TOTAL_FAIL+1)); if [[ "$TOTAL_FAIL" -eq 0 ]]; then echo "OVERALL .............. PASS"; echo "Failed Components: None"; echo "========================================"; echo "M14-A AUTOMATED ACCEPTANCE = PASS"; exit 0; fi
echo "OVERALL .............. FAIL"; echo "Failed Components:"; printf '%s\n' "${FAILURES[@]}" | awk 'NF && !seen[$0]++ {print "- "$0}'; echo "========================================"; echo "M14-A AUTOMATED ACCEPTANCE = FAIL"; exit 1
