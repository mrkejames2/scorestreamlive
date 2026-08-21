#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

: "${BASE_URL:=http://192.168.12.133:8000}"
: "${VALIDATION_MODE:=local}"
: "${VALIDATION_SCOPE:=fast}"
: "${VALIDATION_OUTPUT:=summary}"
: "${VALIDATION_FAIL_FAST:=0}"

echo "[M14-B] Game Library Dashboard validation via modernized harness..."

for required in   scripts/validate.sh   scripts/regression/game_library.sh   scripts/regression/game_dashboard.sh   static/css/games-m14b.css
do
  [[ -e "$required" ]] || { echo "FAIL required M14-B component missing: $required"; exit 1; }
done

BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" VALIDATION_SCOPE="$VALIDATION_SCOPE" VALIDATION_OUTPUT="$VALIDATION_OUTPUT" VALIDATION_FAIL_FAST="$VALIDATION_FAIL_FAST"   ./scripts/validate.sh

echo "M14-B AUTOMATED ACCEPTANCE = PASS"
