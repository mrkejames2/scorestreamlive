#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ACTION="${1:---dry-run}"
SEED="${2:-}"

case "$ACTION" in
  --dry-run|--apply) ;;
  *)
    echo "Usage: $0 [--dry-run|--apply] [--seed]" >&2
    exit 2
    ;;
esac

if [[ -n "$SEED" && "$SEED" != "--seed" ]]; then
  echo "Usage: $0 [--dry-run|--apply] [--seed]" >&2
  exit 2
fi

mkdir -p .validation/db-backups

PSQL=(docker compose exec -T postgres sh -lc
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"')

echo "========================================"
echo "ScoreStreamLive Local Dev Data Reset"
echo "ACTION: $ACTION"
echo "SEED:   ${SEED:-(none)}"
echo "========================================"

echo
echo "[1/4] Current row counts"
docker compose exec -T postgres sh -lc \
  'psql -At -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
    SELECT '\''teams'\'' AS table_name, count(*) FROM teams
    UNION ALL SELECT '\''players'\'', count(*) FROM players
    UNION ALL SELECT '\''games'\'', count(*) FROM games
    UNION ALL SELECT '\''game_clocks'\'', count(*) FROM game_clocks
    UNION ALL SELECT '\''game_lifecycles'\'', count(*) FROM game_lifecycles
    UNION ALL SELECT '\''scoring_events'\'', count(*) FROM scoring_events
    ORDER BY 1;
  "' | column -t -s '|'

if [[ "$ACTION" == "--dry-run" ]]; then
  echo
  echo "DRY RUN ONLY — no data changed."
  echo
  echo "To reset and seed the small M14 dataset:"
  echo "  sudo ./scripts/dev/reset_local_dev_data.sh --apply --seed"
  exit 0
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP=".validation/db-backups/local-domain-data-${STAMP}.sql.gz"

echo
echo "[2/4] Backing up current application-domain data"
docker compose exec -T postgres sh -lc \
  'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    --data-only \
    --table=teams \
    --table=players \
    --table=games \
    --table=game_clocks \
    --table=game_lifecycles \
    --table=scoring_events' \
  | gzip > "$BACKUP"

echo "Backup: $BACKUP"

echo
echo "[3/4] Truncating local application-domain data"
docker compose exec -T postgres sh -lc \
  'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
    BEGIN;
    TRUNCATE TABLE
      scoring_events,
      game_clocks,
      game_lifecycles,
      players,
      games,
      teams;
    COMMIT;
  "'

if [[ "$SEED" == "--seed" ]]; then
  echo
  echo "[4/4] Loading compact M14 demo data"
  cat scripts/dev/seed_m14_demo.sql | \
    docker compose exec -T postgres sh -lc \
      'psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
else
  echo
  echo "[4/4] Seed skipped"
fi

echo
echo "Final row counts"
docker compose exec -T postgres sh -lc \
  'psql -At -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "
    SELECT '\''teams'\'' AS table_name, count(*) FROM teams
    UNION ALL SELECT '\''players'\'', count(*) FROM players
    UNION ALL SELECT '\''games'\'', count(*) FROM games
    UNION ALL SELECT '\''game_clocks'\'', count(*) FROM game_clocks
    UNION ALL SELECT '\''game_lifecycles'\'', count(*) FROM game_lifecycles
    UNION ALL SELECT '\''scoring_events'\'', count(*) FROM scoring_events
    ORDER BY 1;
  "' | column -t -s '|'

echo
echo "PASS: local development data reset complete."
