#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
: "${BASE_URL:=http://127.0.0.1:8000}"
: "${VALIDATION_MODE:=local}"
: "${VALIDATION_SCOPE:=fast}"
: "${VALIDATION_OUTPUT:=summary}"
echo "[M14-HF2] Scoring Corrections & Test Clock validation..."
BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" VALIDATION_SCOPE="$VALIDATION_SCOPE" VALIDATION_OUTPUT="$VALIDATION_OUTPUT" ./scripts/validate.sh
echo "M14-HF2 AUTOMATED ACCEPTANCE = PASS"
