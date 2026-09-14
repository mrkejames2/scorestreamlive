#!/usr/bin/env bash
set -uo pipefail
fail=0
check(){ if eval "$2"; then echo "PASS: $1"; else echo "FAIL: $1"; fail=1; fi; }
echo "========================================"
echo "M18-G3 Overlay / Broadcast Branding"
echo "========================================"
check "effective branding projection exists" "grep -q get_effective_club_branding app/services/effective_branding_service.py"
check "provider-neutral branding runtime" "! grep -qi stripe app/services/effective_branding_service.py"
check "overlay-state exposes branding" "grep -q '\"branding\"' app/api/control.py"
check "public summary exposes branding" "grep -q '\"branding\"' app/services/public_game_summary_service.py"
check "overlay renders Club branding" "grep -q applyClubBranding static/js/overlay/overlay.js && grep -q club-brand-fallback templates/overlay/game.html"
check "broadcast renders Club branding" "grep -q applyClubBranding static/js/public-game-summary.js && grep -q broadcast-club-logo templates/broadcast/game.html"
check "team branding remains present" "grep -q applyOverlayTeamBrand static/js/overlay/overlay.js && grep -q applyTeam static/js/public-game-summary.js"
check "cumulative G2 preserved" "grep -q validate_m18g2.sh scripts/validate_m18g3.sh"
[[ "$fail" -eq 0 ]] || { echo "M18-G3 Overlay / Broadcast Branding: FAIL"; exit 1; }
echo "M18-G3 Overlay / Broadcast Branding: PASS"
