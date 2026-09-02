#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0
APP_CONTAINER=""

check_file() {
  [[ -f "$1" ]] \
    && echo "PASS file $1" \
    || { echo "FAIL missing $1"; fail=1; }
}

check_text() {
  grep -Fq "$2" "$1" \
    && echo "PASS $3" \
    || { echo "FAIL $3"; fail=1; }
}

check_file alembic/versions/20260824_0010_create_users_and_sessions.py
check_file alembic/versions/20260824_0011_add_clubs_and_user_membership.py
check_file alembic/versions/20260824_0012_add_resource_club_scope_and_assignments.py
check_file app/cli/bootstrap_user.py
check_file app/cli/bootstrap_club.py
check_file app/cli/claim_club_resources.py
check_file docs/releases/M15_AUTH_TENANT_RELEASE_RUNBOOK.md

check_text docs/releases/M15_AUTH_TENANT_RELEASE_RUNBOOK.md \
  'python -m app.cli.bootstrap_user' \
  "bootstrap User documented"
check_text docs/releases/M15_AUTH_TENANT_RELEASE_RUNBOOK.md \
  'python -m app.cli.bootstrap_club' \
  "bootstrap Club documented"
check_text docs/releases/M15_AUTH_TENANT_RELEASE_RUNBOOK.md \
  'python -m app.cli.claim_club_resources' \
  "legacy claim documented"
check_text docs/releases/M15_AUTH_TENANT_RELEASE_RUNBOOK.md \
  'VALIDATION_MODE=production' \
  "production validation documented"

if [[ "$VALIDATION_MODE" == "local" ]]; then
  command -v timeout >/dev/null 2>&1 || {
    echo "FAIL timeout command unavailable"
    exit 1
  }

  APP_CONTAINER="$(timeout 10s docker compose ps -q app 2>/dev/null | head -1)"
  if [[ -z "$APP_CONTAINER" ]]; then
    echo "FAIL could not resolve running app container"
    exit 1
  fi

  alembic_output="$(
    timeout --foreground -k 5s 20s docker exec "$APP_CONTAINER" alembic current 2>&1
  )"
  rc=$?

  if [[ "$rc" != "0" ]]; then
    echo "FAIL Alembic current did not complete successfully (rc=$rc)"
    echo "$alembic_output"
    fail=1
  elif grep -Fq '20260902_0013' <<<"$alembic_output"; then
    echo "PASS Alembic head 20260902_0013"
  else
    echo "FAIL Alembic expected 20260902_0013"
    echo "$alembic_output"
    fail=1
  fi
fi

exit "$fail"
