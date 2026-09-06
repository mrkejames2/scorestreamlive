#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# First prove the complete accepted M17 cumulative baseline.
./scripts/validate.sh

# Then prove the new M18-A provider-neutral commercial domain.
echo
echo "========================================"
echo "M18-A Billing Domain & Entitlements"
echo "========================================"
./scripts/regression/billing_domain_entitlements.sh
echo "M18-A Billing Domain & Entitlements... PASS"
