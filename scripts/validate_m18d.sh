#!/usr/bin/env bash
set -uo pipefail
./scripts/validate_m18c.sh || exit 1
./scripts/regression/verified_webhooks_provisioning.sh
