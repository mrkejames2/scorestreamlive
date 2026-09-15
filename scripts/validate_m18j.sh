#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"
VALIDATION_SCOPE="${VALIDATION_SCOPE:-release}"
EXPECTED_HEAD="${EXPECTED_ALEMBIC_HEAD:-20260915_0026}"

echo "========================================"
echo "M18-J Final M18 Release Readiness Gate"
echo "========================================"

# Preserve the cumulative milestone model by delegating to M18-I.
if [[ -x ./scripts/validate_m18i.sh ]]; then
  BASE_URL="$BASE_URL" \
  VALIDATION_SCOPE="$VALIDATION_SCOPE" \
    ./scripts/validate_m18i.sh

  echo "PASS: cumulative M18 validation"
else
  echo "FAIL: scripts/validate_m18i.sh is required for cumulative M18 validation" >&2
  exit 1
fi

EXPECTED_ALEMBIC_HEAD="$EXPECTED_HEAD" \
  ./scripts/regression/final_m18_release_gate.sh

# ---------------------------------------------------------------------------
# M18-J production-safe runtime validation
#
# The normal development environment intentionally may have:
#
#   PUBLIC_CHECKOUT_ENABLED=true
#
# M18-J must prove that the production launch configuration works with:
#
#   BILLING_LIVE_ENABLED=false
#   PUBLIC_CHECKOUT_ENABLED=false
#
# without permanently changing the developer's .env.
# ---------------------------------------------------------------------------

command -v curl >/dev/null 2>&1 || {
  echo "FAIL: curl is required for M18-J runtime validation" >&2
  exit 1
}

command -v docker >/dev/null 2>&1 || {
  echo "FAIL: docker is required for M18-J runtime validation" >&2
  exit 1
}

docker compose version >/dev/null 2>&1 || {
  echo "FAIL: docker compose is required for M18-J runtime validation" >&2
  exit 1
}

restore_m18j_runtime() {
  echo "Restoring normal development runtime..."
  docker compose up -d --force-recreate app >/dev/null
}

wait_for_ready() {
  local ready=0

  for _ in $(seq 1 60); do
    if curl -fsS "${BASE_URL}/health/ready" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 2
  done

  [[ "$ready" == "1" ]]
}

# If validation exits unexpectedly after changing the runtime, restore the
# developer's normal Compose configuration.
trap restore_m18j_runtime EXIT

echo
echo "Applying temporary M18-J production-safe checkout configuration..."

M18J_OVERRIDE="$(mktemp --suffix=.yml)"

cat > "$M18J_OVERRIDE" <<'M18J_COMPOSE_OVERRIDE'
services:
  app:
    environment:
      BILLING_LIVE_ENABLED: "false"
      PUBLIC_CHECKOUT_ENABLED: "false"
M18J_COMPOSE_OVERRIDE

restore_m18j_runtime() {
  echo "Restoring normal development runtime..."
  rm -f "${M18J_OVERRIDE:-}"
  docker compose up -d --force-recreate app >/dev/null
}

# Re-register the EXIT trap now that the override file exists and the
# restoration function knows how to remove it.
trap restore_m18j_runtime EXIT

docker compose   -f docker-compose.yml   -f "$M18J_OVERRIDE"   up -d --force-recreate app >/dev/null

echo "Waiting for application readiness..."

if ! wait_for_ready; then
  echo "FAIL: application did not become ready under M18-J safe configuration" >&2
  exit 1
fi

curl -fsS "${BASE_URL}/health/live" >/dev/null
echo "PASS: production-safe runtime health"

effective_checkout="$(
  docker compose exec -T app sh -lc \
    'printf "%s" "${PUBLIC_CHECKOUT_ENABLED:-<unset>}"'
)"

if [[ "$effective_checkout" != "false" ]]; then
  echo "FAIL: temporary runtime PUBLIC_CHECKOUT_ENABLED=${effective_checkout}" >&2
  exit 1
fi

echo "PASS: temporary runtime public checkout disabled"

effective_live="$(
  docker compose exec -T app sh -lc \
    'printf "%s" "${BILLING_LIVE_ENABLED:-<unset>}"'
)"

if [[ "$effective_live" != "false" ]]; then
  echo "FAIL: temporary runtime BILLING_LIVE_ENABLED=${effective_live}" >&2
  exit 1
fi

echo "PASS: temporary runtime live billing disabled"

plans="$(curl -fsS "${BASE_URL}/api/public/checkout/plans")"

if [[ "$plans" != "[]" ]]; then
  echo "FAIL: public checkout plans expected [], got: ${plans}" >&2
  exit 1
fi

echo "PASS: disabled public checkout plans return []"

# The API validates the request body before reaching the launch gate, so use
# the minimum structurally valid checkout request. No Stripe processing should
# occur because PUBLIC_CHECKOUT_ENABLED=false must short-circuit the request.
checkout_payload='{"signup_intent_id":"00000000-0000-0000-0000-000000000001","plan_code":"M18C_TEST","email":"m18j-validation@example.invalid"}'

tmpfile="$(mktemp)"

status="$(
  curl -sS \
    -o "$tmpfile" \
    -w '%{http_code}' \
    -X POST \
    -H 'Content-Type: application/json' \
    -d "$checkout_payload" \
    "${BASE_URL}/api/public/checkout" || true
)"

if [[ "$status" != "503" ]]; then
  echo "FAIL: disabled public checkout POST expected HTTP 503, got ${status}" >&2
  echo "Response body:" >&2
  cat "$tmpfile" >&2
  rm -f "$tmpfile"
  exit 1
fi

rm -f "$tmpfile"

echo "PASS: disabled public checkout POST returns HTTP 503"

# Restore the developer's normal .env-driven runtime.
restore_m18j_runtime
trap - EXIT

echo "Waiting for normal development runtime to return..."

if ! wait_for_ready; then
  echo "FAIL: normal development runtime did not recover after validation" >&2
  exit 1
fi

restored_checkout="$(
  docker compose exec -T app sh -lc \
    'printf "%s" "${PUBLIC_CHECKOUT_ENABLED:-<unset>}"'
)"

echo "Restored PUBLIC_CHECKOUT_ENABLED=${restored_checkout}"
echo "PASS: normal development runtime restored"

echo
echo "PASS: migration chain terminates at ${EXPECTED_HEAD}"
echo "PASS: no new M18-J migration"
echo "PASS: production data baseline capability"
echo "PASS: production data preservation policy"
echo "PASS: destructive migration safety inspection"
echo "PASS: billing live mode disabled"
echo "PASS: public checkout launch gate available"
echo "PASS: Stripe live/test safety enforcement"
echo "PASS: production HTTPS requirement"
echo "PASS: production backup requirement"
echo "PASS: deployment commit identity procedure"
echo "PASS: deployment runbook"
echo "PASS: application rollback procedure"
echo "PASS: database recovery procedure"
echo "PASS: production acceptance checklist"

echo
echo "M18-J Final M18 Release Readiness Gate: PASS"
