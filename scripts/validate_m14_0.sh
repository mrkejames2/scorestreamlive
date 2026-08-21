#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; cd "$ROOT"
: "${BASE_URL:=http://192.168.12.133:8000}"; : "${VALIDATION_MODE:=local}"; : "${VALIDATION_SCOPE:=fast}"; : "${VALIDATION_OUTPUT:=summary}"; : "${VALIDATION_FAIL_FAST:=0}"
echo '[M14-0] Validating modernized validation harness...'
for f in scripts/validate.sh scripts/lib/validation.sh scripts/regression/health.sh scripts/regression/surfaces.sh scripts/regression/api_reads.sh scripts/regression/architecture.sh scripts/regression/recovery.sh; do [[ -x "$f" ]] || { echo "FAIL required executable missing: $f"; exit 1; }; done
if grep -Eq 'validate_m[0-9]+' scripts/validate.sh; then echo 'FAIL active orchestrator references historical milestone validators'; exit 1; fi
BASE_URL="$BASE_URL" VALIDATION_MODE="$VALIDATION_MODE" VALIDATION_SCOPE="$VALIDATION_SCOPE" VALIDATION_OUTPUT="$VALIDATION_OUTPUT" VALIDATION_FAIL_FAST="$VALIDATION_FAIL_FAST" ./scripts/validate.sh
echo 'M14-0 VALIDATION HARNESS ACCEPTANCE = PASS'
