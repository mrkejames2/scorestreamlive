#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18h.sh || exit 1
./scripts/regression/production_billing_safety.sh
