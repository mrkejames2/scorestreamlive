#!/usr/bin/env bash
set -uo pipefail
fail=0
check(){ if eval "$2";then echo "PASS: $1";else echo "FAIL: $1";fail=1;fi; }
echo "========================================"; echo "M18-G1 Club Branding Domain + Storage"; echo "========================================"
check "ClubBranding model" "grep -Fq '__tablename__ = \"club_branding\"' app/models/club_branding.py"
check "migration chain" "grep -Fq 'down_revision=\"20260910_0023\"' alembic/versions/20260913_0024_add_club_branding.py"
check "Director tenant boundary" "grep -q _require_director_club app/api/club_branding.py"
check "premium entitlement enforced" "grep -q CUSTOM_OVERLAY_BRANDING app/api/club_branding.py && grep -q require_entitlement app/api/club_branding.py"
check "validated storage" "grep -q CLUB_BRANDING_MAX_BYTES app/services/club_branding_storage.py && grep -q image/webp app/services/club_branding_storage.py"
check "immutable asset delivery" "grep -q immutable app/api/club_branding.py"
check "cumulative M18-F preserved" "grep -q validate_m18f.sh scripts/validate_m18g1.sh"
[[ $fail -eq 0 ]]||exit 1
echo "M18-G1 Club Branding Domain + Storage: PASS"
