#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18g1.sh || exit 1
./scripts/regression/branding_management_ux.sh
