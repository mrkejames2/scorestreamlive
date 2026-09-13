#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18f.sh || exit 1
./scripts/regression/club_branding_domain_storage.sh
