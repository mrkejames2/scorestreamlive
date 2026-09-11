#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18d.sh || exit 1
./scripts/regression/account_activation.sh
