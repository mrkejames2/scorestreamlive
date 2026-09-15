#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
EXPECTED_HEAD="${EXPECTED_ALEMBIC_HEAD:-20260915_0026}"

echo "========================================"
echo "M18-J Production Release Preflight"
echo "========================================"
echo "BASE_URL: ${BASE_URL}"
echo "Expected Alembic head: ${EXPECTED_HEAD}"
echo

if [[ "$BASE_URL" != "http://127.0.0.1:8000" && "$BASE_URL" != https://* ]]; then
  echo "FAIL: BASE_URL must be local 127.0.0.1:8000 or HTTPS." >&2
  exit 1
fi
echo "PASS: base URL safety"

command -v git >/dev/null || { echo "FAIL: git unavailable" >&2; exit 1; }
git rev-parse --show-toplevel >/dev/null
echo "PASS: repository detected"

if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  compose_services="$(docker compose config --services 2>/dev/null)"

  if grep -Fxq "app" <<<"$compose_services"; then
    echo "PASS: Docker Compose app service detected"
  else
    echo "FAIL: Docker Compose app service not detected" >&2
    exit 1
  fi

  if grep -Fxq "postgres" <<<"$compose_services"; then
    echo "PASS: Docker Compose postgres service detected"
  else
    echo "FAIL: Docker Compose postgres service not detected" >&2
    exit 1
  fi
else
  echo "WARN: Docker Compose unavailable to preflight; runtime checks will be delegated to cumulative validation."
fi

for endpoint in /health/live /health/ready; do
  if command -v curl >/dev/null 2>&1; then
    curl -fsS "${BASE_URL}${endpoint}" >/dev/null
    echo "PASS: ${endpoint}"
  else
    echo "WARN: curl unavailable; skipped ${endpoint}"
  fi
done

echo
echo "PRE-MERGE HUMAN CHECKLIST"
echo "[ ] Record PRE_M18_COMMIT (known-good production/main SHA)"
echo "[ ] Record M18_RELEASE_COMMIT (final cumulative M18 SHA)"
echo "[ ] Verify Render APP_ENV=production"
echo "[ ] Verify Render PUBLIC_BASE_URL uses HTTPS"
echo "[ ] Verify BILLING_PROVIDER=stripe"
echo "[ ] Verify BILLING_LIVE_ENABLED=false"
echo "[ ] Verify PUBLIC_CHECKOUT_ENABLED=false"
echo "[ ] Verify Stripe secret is NOT a live key while live billing is disabled"
echo "[ ] Create/verify recoverable production PostgreSQL backup/snapshot"
echo "[ ] Capture PRE production baseline using scripts/production_m18j_baseline.sh"
echo "[ ] Confirm Render deploys only after main changes"
echo
echo "M18-J preflight complete. This does NOT constitute production acceptance."
