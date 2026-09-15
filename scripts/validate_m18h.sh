#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18g3.sh || exit 1
./scripts/regression/billing_lifecycle_recovery.sh
./scripts/regression/billing_lifecycle_ux_hardening.sh
