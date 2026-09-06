#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.."&&pwd)";cd "$ROOT"
./scripts/validate_m18a.sh
echo;echo "========================================";echo "M18-B Public Signup & Onboarding";echo "========================================"
./scripts/regression/public_signup_onboarding.sh
echo "M18-B Public Signup & Onboarding... PASS"
