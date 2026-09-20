#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-baseline}"; case "$MODE" in pre|post|baseline);; *) echo "Usage: $0 [pre|post|baseline]" >&2; exit 2;; esac
command -v psql >/dev/null 2>&1 || { echo 'ERROR: psql required' >&2; exit 1; }; [[ -n "${DATABASE_URL:-}" ]] || { echo 'ERROR: DATABASE_URL required' >&2; exit 1; }
sql_value(){ psql "$DATABASE_URL" -X -qAt -v ON_ERROR_STOP=1 -c "$1"; }
echo '========================================'; echo 'ScoreStreamLive M19-I Production Baseline'; echo "Mode: $MODE"; echo "Timestamp UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"; echo '========================================'
echo "database=$(sql_value 'select current_database();')"
echo "alembic_revision=$(sql_value "select case when to_regclass('public.alembic_version') is null then 'N/A' else coalesce((select version_num from alembic_version limit 1),'N/A') end;" 2>/dev/null || echo N/A)"
count_table(){ local t="$1"; if [[ "$(sql_value "select to_regclass('public.${t}') is not null;")" == t ]]; then echo "${t}=$(sql_value "select count(*) from public.\"${t}\";")"; else echo "${t}=N/A"; fi; }
for t in users clubs teams games sponsors game_sponsors game_sponsor_presentations sponsor_impressions game_broadcast_presentations; do count_table "$t"; done
echo 'READ-ONLY M19 BASELINE COMPLETE'
