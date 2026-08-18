#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BASE_URL="${BASE_URL:-http://localhost:8000}"
export BASE_URL

PASS=0
FAIL=0

pass(){ echo "[PASS] $1"; PASS=$((PASS+1)); }
fail(){ echo "[FAIL] $1"; FAIL=$((FAIL+1)); }

echo "========================================"
echo "ScoreStreamLive M12-D1 Team Branding Persistence + API"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info /api/teams; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

echo ""
echo "========================================"
echo "Alembic / Static Architecture Checks"
echo "========================================"

CURRENT=$(docker compose exec -T app alembic current 2>&1 || true)
echo "$CURRENT"

grep -Fq "20260818_0008" <<<"$CURRENT" \
  && pass "Alembic current includes M12-D1 revision 0008" \
  || fail "Alembic current does not include M12-D1 revision 0008"

grep -Fq 'logo_url' app/models/team.py \
  && pass "Team model includes logo_url" \
  || fail "Team model missing logo_url"

grep -Fq 'primary_color' app/models/team.py \
  && pass "Team model includes primary_color" \
  || fail "Team model missing primary_color"

grep -Fq 'secondary_color' app/models/team.py \
  && pass "Team model includes secondary_color" \
  || fail "Team model missing secondary_color"

grep -Fq 'logo_url' app/schemas/team.py \
  && grep -Fq 'HEX_COLOR_PATTERN' app/schemas/team.py \
  && pass "Team schemas expose branding with hex-color validation" \
  || fail "Team branding schema contract missing"

grep -Fq '"logo_url": team.logo_url' app/services/team_service.py \
  && grep -Fq '"primary_color": team.primary_color' app/services/team_service.py \
  && grep -Fq '"secondary_color": team.secondary_color' app/services/team_service.py \
  && pass "Socket.IO Team serialization includes branding" \
  || fail "Socket.IO Team branding serialization missing"

TMP=$(mktemp)
set +e

docker compose exec -T -e BASE_URL="$BASE_URL" app python3 - <<'PY' >"$TMP" 2>&1
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE=os.environ["BASE_URL"]
stamp=int(time.time())
p=f=0

def check(label, cond):
    global p,f
    if cond:
        print(f"[PASS] {label}", flush=True)
        p+=1
    else:
        print(f"[FAIL] {label}", flush=True)
        f+=1

def req(method,path,payload=None,allow=False):
    data=None
    headers={}
    if payload is not None:
        data=json.dumps(payload).encode()
        headers["Content-Type"]="application/json"

    r=urllib.request.Request(
        BASE+path,
        data=data,
        headers=headers,
        method=method,
    )

    try:
        with urllib.request.urlopen(r,timeout=15) as x:
            raw=x.read()
            ct=x.headers.get("Content-Type","")
            body=(
                json.loads(raw)
                if raw and "application/json" in ct.lower()
                else raw.decode(errors="replace")
            )
            return x.status,body,ct
    except urllib.error.HTTPError as e:
        raw=e.read()
        try:
            body=json.loads(raw) if raw else None
        except Exception:
            body=raw.decode(errors="replace")
        if allow:
            return e.code,body,e.headers.get("Content-Type","")
        raise

name=f"M12-D1 Branded Team {stamp}"

status,team,_=req("POST","/api/teams",{
    "name":name,
    "short_name":"D1",
    "logo_url":"/static/uploads/team-logos/m12-d1-test.png",
    "primary_color":"#003B71",
    "secondary_color":"#FFFFFF",
})

check("Branded Team create returns 201",status==201)
check("Branded Team name persisted",team.get("name")==name)
check("Branded Team short name persisted",team.get("short_name")=="D1")
check(
    "Branded Team logo_url persisted",
    team.get("logo_url")=="/static/uploads/team-logos/m12-d1-test.png",
)
check("Branded Team primary color persisted",team.get("primary_color")=="#003B71")
check("Branded Team secondary color persisted",team.get("secondary_color")=="#FFFFFF")

fresh=req("GET",f"/api/teams/{team['id']}")[1]

check("GET Team returns logo_url",fresh.get("logo_url")==team.get("logo_url"))
check("GET Team returns primary color",fresh.get("primary_color")=="#003B71")
check("GET Team returns secondary color",fresh.get("secondary_color")=="#FFFFFF")

_,teams,_=req("GET","/api/teams")
listed=next((x for x in teams if x.get("id")==team["id"]),None)

check("LIST Teams includes branded Team",listed is not None)
check(
    "LIST Teams preserves branding",
    listed is not None
    and listed.get("logo_url")==team.get("logo_url")
    and listed.get("primary_color")=="#003B71"
    and listed.get("secondary_color")=="#FFFFFF",
)

updated=req("PATCH",f"/api/teams/{team['id']}",{
    "primary_color":"#112233",
    "secondary_color":"#AABBCC",
})[1]

check("PATCH Team updates primary color",updated.get("primary_color")=="#112233")
check("PATCH Team updates secondary color",updated.get("secondary_color")=="#AABBCC")
check("PATCH Team preserves logo_url",updated.get("logo_url")==team.get("logo_url"))

legacy=req("POST","/api/teams",{
    "name":f"M12-D1 Legacy Team {stamp}",
    "short_name":"LEG",
})[1]

check("Legacy Team creation remains supported",legacy.get("name","").startswith("M12-D1 Legacy"))
check("Legacy Team logo defaults null",legacy.get("logo_url") is None)
check("Legacy Team primary color defaults null",legacy.get("primary_color") is None)
check("Legacy Team secondary color defaults null",legacy.get("secondary_color") is None)

bad_status,_,_=req("POST","/api/teams",{
    "name":f"M12-D1 Bad Color {stamp}",
    "primary_color":"blue",
},allow=True)

check("Invalid color is rejected with 422",bad_status==422)

print("========================================")
print(f"M12-D1 Python Tests Passed: {p} Failed: {f}")
print("========================================")
sys.exit(1 if f else 0)
PY

RC=$?
set -e
cat "$TMP"

P=$(grep -oP 'M12-D1 Python Tests Passed: \K[0-9]+' "$TMP" | tail -1 || true)
F=$(grep -oP 'Failed: \K[0-9]+' "$TMP" | tail -1 || true)

PASS=$((PASS + ${P:-0}))
FAIL=$((FAIL + ${F:-0}))
rm -f "$TMP"

[ "$RC" -eq 0 ] \
  && pass "M12-D1 Team branding API process passed" \
  || fail "M12-D1 Team branding API process failed"

echo ""
echo "========================================"
echo "Running M12-C regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12c.sh
M12C_RC=$?
set -e

[ "$M12C_RC" -eq 0 ] \
  && pass "M12-C regression passed" \
  || fail "M12-C regression failed"

echo ""
echo "========================================"
if [ "$FAIL" -eq 0 ]; then
  echo "M12-D1 VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-D1 VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
