#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18e2.sh || exit 1
./scripts/regression/entitlement_enforcement.sh
