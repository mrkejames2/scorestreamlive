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
echo "ScoreStreamLive M12-D2 Team Logo Upload + Storage"
echo "BASE_URL: ${BASE_URL}"
echo "========================================"

for path in /health/live /health/ready /info /api/teams; do
  code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}${path}" || true)
  [ "$code" = "200" ] && pass "$path" || fail "$path HTTP ${code}"
done

grep -Fq "python-multipart" requirements.txt \
  && pass "Multipart upload dependency present" \
  || fail "python-multipart dependency missing"

grep -Fq 'TEAM_LOGO_STORAGE_DIR' app/config.py \
  && pass "Configurable Team logo storage path exists" \
  || fail "Team logo storage path configuration missing"

grep -Fq 'TEAM_LOGO_MAX_BYTES' app/config.py \
  && pass "Configurable Team logo size limit exists" \
  || fail "Team logo size-limit configuration missing"

grep -Fq 'save_team_logo' app/services/team_logo_storage.py \
  && grep -Fq 'detect_image_format' app/services/team_logo_storage.py \
  && pass "Logo storage validates file signatures" \
  || fail "Logo file-signature validation missing"

grep -Fq '@router.post("/{team_id}/logo"' app/api/teams.py \
  && pass "Team logo upload endpoint exists" \
  || fail "Team logo upload endpoint missing"

grep -Fq 'APIRouter(prefix="/api/team-logos"' app/api/team_logos.py \
  && pass "Public Team logo delivery endpoint exists" \
  || fail "Team logo delivery endpoint missing"

grep -Fq 'team_logo_data:/home/appuser/app/static/uploads/team-logos' docker-compose.yml \
  && pass "Local Docker logo persistence volume exists" \
  || fail "Local Docker logo persistence volume missing"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 1x1 transparent PNG.
python3 - <<'PY' "$TMP/logo.png"
import base64,sys
data=base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
)
open(sys.argv[1],"wb").write(data)
PY

TEAM_JSON=$(curl -fsS \
  -H "Content-Type: application/json" \
  -d '{"name":"M12-D2 Upload Team","short_name":"D2","primary_color":"#003B71","secondary_color":"#FFFFFF"}' \
  "${BASE_URL}/api/teams")

TEAM_ID=$(python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])' <<<"$TEAM_JSON")

[ -n "$TEAM_ID" ] \
  && pass "D2 test Team created" \
  || fail "D2 test Team creation failed"

UPLOAD_JSON="$TMP/upload.json"
UPLOAD_CODE=$(curl -sS \
  -o "$UPLOAD_JSON" \
  -w "%{http_code}" \
  -F "logo=@$TMP/logo.png;type=image/png" \
  "${BASE_URL}/api/teams/${TEAM_ID}/logo" || true)

[ "$UPLOAD_CODE" = "200" ] \
  && pass "PNG logo upload returns 200" \
  || fail "PNG logo upload HTTP ${UPLOAD_CODE}"

LOGO_URL=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("logo_url",""))' <"$UPLOAD_JSON")

[[ "$LOGO_URL" == /api/team-logos/* ]] \
  && pass "Upload returns persistent logo URL contract" \
  || fail "Upload did not return /api/team-logos URL"

LOGO_GET_CODE=$(curl -sS \
  -o "$TMP/downloaded-logo" \
  -w "%{http_code}" \
  "${BASE_URL}${LOGO_URL}" || true)

[ "$LOGO_GET_CODE" = "200" ] \
  && pass "Stored logo is publicly retrievable" \
  || fail "Stored logo retrieval HTTP ${LOGO_GET_CODE}"

cmp -s "$TMP/logo.png" "$TMP/downloaded-logo" \
  && pass "Retrieved logo bytes match upload" \
  || fail "Retrieved logo bytes differ from upload"

FRESH_JSON=$(curl -fsS "${BASE_URL}/api/teams/${TEAM_ID}")
FRESH_LOGO=$(python3 -c 'import json,sys; print(json.load(sys.stdin).get("logo_url",""))' <<<"$FRESH_JSON")

[ "$FRESH_LOGO" = "$LOGO_URL" ] \
  && pass "Team REST state persists logo_url" \
  || fail "Team REST state lost logo_url"

echo "not an image" > "$TMP/not-image.txt"

BAD_CODE=$(curl -sS \
  -o "$TMP/bad.json" \
  -w "%{http_code}" \
  -F "logo=@$TMP/not-image.txt;type=text/plain" \
  "${BASE_URL}/api/teams/${TEAM_ID}/logo" || true)

[ "$BAD_CODE" = "415" ] \
  && pass "Unsupported upload is rejected 415" \
  || fail "Unsupported upload expected 415, got ${BAD_CODE}"

python3 - <<'PY' "$TMP/too-big.png"
import sys
limit=2097152
with open(sys.argv[1],"wb") as f:
    f.write(b"\x89PNG\r\n\x1a\n")
    f.write(b"\0" * (limit + 1))
PY

BIG_CODE=$(curl -sS \
  -o "$TMP/big.json" \
  -w "%{http_code}" \
  -F "logo=@$TMP/too-big.png;type=image/png" \
  "${BASE_URL}/api/teams/${TEAM_ID}/logo" || true)

[ "$BIG_CODE" = "413" ] \
  && pass "Oversized upload is rejected 413" \
  || fail "Oversized upload expected 413, got ${BIG_CODE}"

MISSING_ID="00000000-0000-0000-0000-000000000001"
MISSING_CODE=$(curl -sS \
  -o "$TMP/missing.json" \
  -w "%{http_code}" \
  -F "logo=@$TMP/logo.png;type=image/png" \
  "${BASE_URL}/api/teams/${MISSING_ID}/logo" || true)

[ "$MISSING_CODE" = "404" ] \
  && pass "Missing Team logo upload is rejected 404" \
  || fail "Missing Team expected 404, got ${MISSING_CODE}"

CONTAINER_FILE=$(docker compose exec -T app python3 - <<PY
from app.config import settings
from pathlib import Path
u="${LOGO_URL}"
name=u.rsplit("/",1)[-1]
p=Path(settings.TEAM_LOGO_STORAGE_DIR)/name
print("yes" if p.is_file() else "no")
PY
)

[ "$CONTAINER_FILE" = "yes" ] \
  && pass "Logo exists in configured container storage" \
  || fail "Logo not found in configured container storage"

echo ""
echo "========================================"
echo "Running M12-D1 regression"
echo "========================================"

set +e
BASE_URL="$BASE_URL" ./scripts/validate_m12d1.sh
D1_RC=$?
set -e

[ "$D1_RC" -eq 0 ] \
  && pass "M12-D1 regression passed" \
  || fail "M12-D1 regression failed"

echo ""
echo "========================================"

if [ "$FAIL" -eq 0 ]; then
  echo "M12-D2 VALIDATION PASSED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 0
else
  echo "M12-D2 VALIDATION FAILED"
  echo "Passed: $PASS Failed: $FAIL"
  echo "========================================"
  exit 1
fi
