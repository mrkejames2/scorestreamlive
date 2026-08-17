#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
PASS=0
FAIL=0

pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

is_local_target() {
    case "$BASE_URL" in
        http://localhost:*|https://localhost:*|\
        http://127.0.0.1:*|https://127.0.0.1:*|\
        http://192.168.*|https://192.168.*|\
        http://10.*|https://10.*|\
        http://172.16.*|http://172.17.*|http://172.18.*|http://172.19.*|\
        http://172.2?.*|http://172.3[01].*)
            return 0 ;;
        *) return 1 ;;
    esac
}

run_harness() {
    local label="$1"
    local script="$2"
    local out rc cp cf
    out=$(mktemp)

    echo ""
    echo "========================================"
    echo "Running ${label}"
    echo "========================================"

    set +e
    BASE_URL="$BASE_URL" "$script" 2>&1 | tee "$out"
    rc=${PIPESTATUS[0]}
    set -e

    cp=$(grep -oP 'Passed: \K[0-9]+' "$out" | tail -1 || true)
    cf=$(grep -oP 'Failed: \K[0-9]+' "$out" | tail -1 || true)
    cp="${cp:-0}"
    cf="${cf:-0}"

    PASS=$((PASS + cp))
    FAIL=$((FAIL + cf))
    rm -f "$out"

    if [ "$rc" -eq 0 ]; then
        pass "${label} process passed"
    else
        fail "${label} process failed with exit code ${rc}"
    fi
}

restart_active_phase_test() {
    echo ""
    echo "========================================"
    echo "M9 Application Restart During First Half"
    echo "========================================"

    local state
    state=$(BASE_URL="$BASE_URL" python3 - <<'PY'
import json, os, time, urllib.request
base=os.environ["BASE_URL"]
prefix=f"M9-RESTART-{int(time.time())}"

def req(method,path,payload=None):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode(); headers["Content-Type"]="application/json"
    r=urllib.request.Request(base+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=10) as x:
        return json.loads(x.read())

a=req("POST","/api/teams",{"name":prefix+"-A","short_name":"A"})
b=req("POST","/api/teams",{"name":prefix+"-B","short_name":"B"})
g=req("POST","/api/games",{
    "name":prefix+"-GAME",
    "home_team_id":a["id"],
    "away_team_id":b["id"],
})
req("POST",f"/api/games/{g['id']}/lifecycle",{})
req("POST",f"/api/games/{g['id']}/clock",{
    "mode":"count_up","duration_seconds":2700,
})
r=req("POST",f"/api/games/{g['id']}/lifecycle/transition",{
    "action":"start_first_half",
    "expected_lifecycle_version":1,
    "expected_clock_version":1,
})
print(json.dumps({
    "game_id":g["id"],
    "lifecycle_version":r["lifecycle"]["version"],
    "clock_version":r["clock"]["version"],
    "elapsed_before":r["clock"]["authoritative_elapsed_seconds"],
}))
PY
)

    local game_id lv cv before
    game_id=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['game_id'])")
    lv=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['lifecycle_version'])")
    cv=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['clock_version'])")
    before=$(echo "$state" | python3 -c "import sys,json; print(json.load(sys.stdin)['elapsed_before'])")

    sleep 2

    if docker compose restart app >/dev/null 2>&1; then
        pass "Application restarted during first_half"
    else
        fail "Application restart failed"
        return
    fi

    local ready=0
    for _ in $(seq 1 30); do
        code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/health/ready" || true)
        if [ "$code" = "200" ]; then ready=1; break; fi
        sleep 1
    done

    [ "$ready" -eq 1 ] && pass "Application ready after M9 restart" || { fail "Application not ready after restart"; return; }

    local lifecycle clock phase status after newlv newcv
    lifecycle=$(curl -s "${BASE_URL}/api/games/${game_id}/lifecycle")
    clock=$(curl -s "${BASE_URL}/api/games/${game_id}/clock")

    phase=$(echo "$lifecycle" | python3 -c "import sys,json; print(json.load(sys.stdin)['phase'])")
    newlv=$(echo "$lifecycle" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    status=$(echo "$clock" | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])")
    newcv=$(echo "$clock" | python3 -c "import sys,json; print(json.load(sys.stdin)['version'])")
    after=$(echo "$clock" | python3 -c "import sys,json; print(json.load(sys.stdin)['authoritative_elapsed_seconds'])")

    [ "$phase" = "first_half" ] && pass "Lifecycle remains first_half after restart" || fail "Lifecycle phase changed after restart"
    [ "$newlv" = "$lv" ] && pass "Lifecycle version survives restart unchanged" || fail "Lifecycle version changed across restart"
    [ "$status" = "running" ] && pass "Clock remains running after M9 restart" || fail "Clock not running after restart"
    [ "$newcv" = "$cv" ] && pass "Clock version survives M9 restart unchanged" || fail "Clock version changed across restart"
    [ "$after" -gt "$before" ] && pass "Clock elapsed includes M9 restart interval" || fail "Clock did not advance across restart"

    local code
    code=$(curl -s -o /tmp/m9_restart_end.json -w "%{http_code}" \
      -X POST "${BASE_URL}/api/games/${game_id}/lifecycle/transition" \
      -H "Content-Type: application/json" \
      -d "{\"action\":\"end_first_half\",\"expected_lifecycle_version\":${newlv},\"expected_clock_version\":${newcv}}")

    [ "$code" = "200" ] && pass "Lifecycle transition succeeds after restart" || fail "Post-restart lifecycle transition returned ${code}"
    rm -f /tmp/m9_restart_end.json
}

echo "========================================"
echo "ScoreStreamLive Final Milestone 9 Validation"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

if is_local_target; then
    current=$(docker compose exec -T app alembic current 2>/dev/null || true)
    if grep -F "20260815_0006" <<< "$current" >/dev/null; then
        pass "Alembic current is 20260815_0006"
    else
        fail "Alembic current is not 20260815_0006"
    fi

    run_harness "M9-D real-time validation" "./scripts/validate_m9d.sh"
    run_harness "M9-C atomic integration regression" "./scripts/validate_m9c.sh"
    run_harness "M9-B lifecycle regression" "./scripts/validate_m9b.sh"
    run_harness "M9-A persistence regression" "./scripts/validate_m9a.sh"
    run_harness "M8 full regression" "./scripts/validate_m8.sh"
    restart_active_phase_test
else
    echo "[INFO] Remote production target detected."
    echo "[INFO] Confirm migration 20260815_0006 separately in Render deployment logs."

    run_harness "M9-D remote real-time validation" "./scripts/validate_m9d.sh"
    run_harness "M9-C remote atomic integration regression" "./scripts/validate_m9c.sh"

    if [ -x "./scripts/validate_m7.sh" ]; then
        run_harness "M7 production regression" "./scripts/validate_m7.sh"
    fi
fi

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
    echo "M9 VALIDATION PASSED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 0
else
    echo "M9 VALIDATION FAILED"
    echo "Passed: $PASS Failed: $FAIL"
    echo "========================================"
    exit 1
fi