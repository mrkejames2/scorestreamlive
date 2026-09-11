#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18e1.sh || exit 1
./scripts/regression/billing_management.sh
