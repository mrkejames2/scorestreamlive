#!/usr/bin/env bash
set -uo pipefail
fail=0
check(){ if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
echo "========================================"
echo "M18-G2 Branding Management UX"
echo "========================================"
check "branding page route exists" "grep -q '/account/branding' app/web/branding.py"
check "Director-only page boundary" "grep -q 'DIRECTOR' app/web/branding.py && grep -q 'Director access required' app/web/branding.py"
check "locked premium state discoverable" "grep -q 'Manage Billing' templates/account/branding.html && grep -q 'branding_enabled' templates/account/branding.html"
check "live preview exists" "grep -q 'branding-preview' templates/account/branding.html && grep -q 'renderPreview' static/js/branding.js"
check "G1 API reused" "grep -q '/api/account/branding' static/js/branding.js && grep -q 'method:\"PATCH\"' static/js/branding.js && grep -q 'method:\"DELETE\"' static/js/branding.js"
check "account links Branding" "grep -q 'href=\"/account/branding\"' templates/account/index.html"
check "cumulative G1 preserved" "grep -q validate_m18g1.sh scripts/validate_m18g2.sh"
[[ "$fail" -eq 0 ]] || { echo "M18-G2 Branding Management UX: FAIL"; exit 1; }
echo "M18-G2 Branding Management UX: PASS"
