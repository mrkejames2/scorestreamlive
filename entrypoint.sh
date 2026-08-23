#!/bin/bash
set -euo pipefail

echo "Running database migrations..."
alembic upgrade head

if [[ "${M15_BOOTSTRAP_ENABLED:-false}" == "true" ]]; then
  echo "M15 production bootstrap enabled."

  : "${AUTH_BOOTSTRAP_EMAIL:?AUTH_BOOTSTRAP_EMAIL is required when M15_BOOTSTRAP_ENABLED=true}"
  : "${AUTH_BOOTSTRAP_PASSWORD:?AUTH_BOOTSTRAP_PASSWORD is required when M15_BOOTSTRAP_ENABLED=true}"
  : "${CLUB_BOOTSTRAP_NAME:?CLUB_BOOTSTRAP_NAME is required when M15_BOOTSTRAP_ENABLED=true}"

  export CLUB_BOOTSTRAP_USER_EMAIL="${CLUB_BOOTSTRAP_USER_EMAIL:-$AUTH_BOOTSTRAP_EMAIL}"
  export RESOURCE_CLAIM_USER_EMAIL="${RESOURCE_CLAIM_USER_EMAIL:-$AUTH_BOOTSTRAP_EMAIL}"

  echo "Ensuring bootstrap Director user exists..."
  python -m app.cli.bootstrap_user

  echo "Ensuring bootstrap Club exists and Director is assigned..."
  python -m app.cli.bootstrap_club

  echo "Claiming any legacy unscoped Teams and Games..."
  python -m app.cli.claim_club_resources

  echo "M15 production bootstrap complete."
else
  echo "M15 production bootstrap disabled."
fi

echo "Starting application..."
exec uvicorn app.main:socket_app --host 0.0.0.0 --port 8000
