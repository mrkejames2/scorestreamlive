#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18g2.sh || exit 1
./scripts/regression/overlay_broadcast_branding.sh
