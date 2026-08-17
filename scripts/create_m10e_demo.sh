#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${BASE_URL:-http://192.168.12.133:8000}"
export BASE_URL
python3 - <<'PY'
import json, os, time, urllib.request
BASE=os.environ["BASE_URL"]; stamp=int(time.time())
def req(method,path,payload=None):
    data=None; headers={}
    if payload is not None:
        data=json.dumps(payload).encode(); headers["Content-Type"]="application/json"
    r=urllib.request.Request(BASE+path,data=data,headers=headers,method=method)
    with urllib.request.urlopen(r,timeout=15) as x:
        raw=x.read(); return json.loads(raw) if raw else None
h=req("POST","/api/teams",{"name":f"Saginaw United Demo {stamp}","short_name":"SAG"})
a=req("POST","/api/teams",{"name":f"Detroit City Demo {stamp}","short_name":"DCFC"})
g=req("POST","/api/games",{"name":f"ScoreStreamLive M10-E Demo {stamp}","home_team_id":h["id"],"away_team_id":a["id"]})
req("POST",f"/api/games/{g['id']}/lifecycle",{})
req("POST",f"/api/games/{g['id']}/clock",{"mode":"count_up","duration_seconds":2700})
for first,last,num in [("Ace","James",17),("Wyatt","James",7),("Maverick","James",22),("Alex","Morgan",10)]:
    req("POST","/api/players",{"team_id":h["id"],"first_name":first,"last_name":last,"jersey_number":num})
for first,last,num in [("Jordan","Smith",9),("Cameron","Lee",11),("Taylor","Brown",8),("Logan","Davis",14)]:
    req("POST","/api/players",{"team_id":a["id"],"first_name":first,"last_name":last,"jersey_number":num})
print()
print("="*68)
print(" SCORESTREAMLIVE M10-E HUMAN CHECKPOINT DEMO")
print("="*68)
print("Game ID:",g["id"])
print("Control Center:")
print(f"{BASE}/control/games/{g['id']}")
print("Expected: PREGAME | 0-0 | 00:00")
print("="*68)
PY
