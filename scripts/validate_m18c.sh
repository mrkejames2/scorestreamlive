#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18b.sh || exit 1
./scripts/regression/hosted_checkout.sh
