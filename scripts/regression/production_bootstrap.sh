#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0

check() {
  local description="$1"
  local pattern="$2"
  local file="$3"
  if grep -Fq "$pattern" "$file"; then
    echo "PASS $description"
  else
    echo "FAIL $description"
    fail=1
  fi
}

check "startup migration preserved" \
  'alembic upgrade head' \
  entrypoint.sh

check "bootstrap opt-in guard" \
  'M15_BOOTSTRAP_ENABLED' \
  entrypoint.sh

check "bootstrap email required" \
  'AUTH_BOOTSTRAP_EMAIL' \
  entrypoint.sh

check "bootstrap password required" \
  'AUTH_BOOTSTRAP_PASSWORD' \
  entrypoint.sh

check "bootstrap Club required" \
  'CLUB_BOOTSTRAP_NAME' \
  entrypoint.sh

check "bootstrap User invoked" \
  'python -m app.cli.bootstrap_user' \
  entrypoint.sh

check "bootstrap Club invoked" \
  'python -m app.cli.bootstrap_club' \
  entrypoint.sh

check "legacy resources claimed" \
  'python -m app.cli.claim_club_resources' \
  entrypoint.sh

check "server starts after bootstrap" \
  'exec uvicorn app.main:socket_app' \
  entrypoint.sh

exit "$fail"
