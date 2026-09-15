#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-baseline}"
case "$MODE" in
  pre|post|baseline) ;;
  *)
    echo "Usage: $0 [pre|post|baseline]" >&2
    exit 2
    ;;
esac

if ! command -v psql >/dev/null 2>&1; then
  echo "ERROR: psql is required for the read-only production baseline." >&2
  exit 1
fi

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "ERROR: DATABASE_URL must point to the database being baselined." >&2
  exit 1
fi

timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

echo "========================================"
echo "ScoreStreamLive M18-J Production Baseline"
echo "Mode: ${MODE}"
echo "Timestamp UTC: ${timestamp}"
echo "========================================"

sql_value() {
  psql "$DATABASE_URL" -X -qAt -v ON_ERROR_STOP=1 -c "$1"
}

echo "database=$(sql_value "select current_database();")"

alembic_revision="$(sql_value "select case when to_regclass('public.alembic_version') is null then 'N/A' else coalesce((select version_num from alembic_version limit 1),'N/A') end;" 2>/dev/null || echo "N/A")"
echo "alembic_revision=${alembic_revision}"

count_candidates() {
  local label="$1"
  shift
  local table=""
  local candidate
  for candidate in "$@"; do
    if [[ "$(sql_value "select to_regclass('public.${candidate}') is not null;")" == "t" ]]; then
      table="$candidate"
      break
    fi
  done

  if [[ -z "$table" ]]; then
    echo "${label}=N/A"
    return 0
  fi

  local count
  count="$(sql_value "select count(*) from public.\"${table}\";")"
  echo "${label}=${count} (table=${table})"
}

# Candidate names are intentionally conservative. Unknown schemas report N/A
# instead of querying or mutating an assumed table.
count_candidates "users" "users" "user"
count_candidates "clubs" "clubs" "club"
count_candidates "teams" "teams" "team"
count_candidates "games" "games" "game"
count_candidates "scoring_events" "scoring_events" "scoring_event" "score_events" "goal_events"

echo "========================================"
echo "READ-ONLY BASELINE COMPLETE"
echo "Retain this output with the deployment record."
echo "========================================"
