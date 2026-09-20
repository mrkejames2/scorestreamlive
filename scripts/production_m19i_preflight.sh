#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"; EXPECTED_HEAD="${EXPECTED_ALEMBIC_HEAD:-20260920_0031}"
echo '=== M19-I Production Preflight ==='
[[ "$BASE_URL" == 'http://127.0.0.1:8000' || "$BASE_URL" == https://* ]] || { echo 'FAIL: BASE_URL must be local or HTTPS' >&2; exit 1; }
for f in scripts/validate_m19i.sh scripts/production_m19i_baseline.sh scripts/final_m19_release_gate.sh docs/M19-I_FINAL_PRODUCTION_RELEASE_GATE.md; do test -f "$f" || { echo "FAIL: missing $f" >&2; exit 1; }; done; echo 'PASS: release files present'
ready=0; for attempt in $(seq 1 30); do if curl -fsS "${BASE_URL}/health/ready" >/dev/null 2>&1; then echo "PASS: readiness ${attempt}/30"; ready=1; break; fi; sleep 2; done
if [[ "$ready" -ne 1 ]]; then echo 'FAIL: readiness timeout' >&2; if command -v docker >/dev/null 2>&1; then sudo docker compose ps || true; sudo docker compose logs --tail=120 app || true; fi; exit 1; fi
curl -fsS "${BASE_URL}/health/live" >/dev/null; echo 'PASS: /health/live'
if command -v docker >/dev/null 2>&1 && sudo docker compose ps app >/dev/null 2>&1; then
sudo docker compose exec -T app python3 - <<'PY2'
import os

for k in ('DB_HOST','DB_NAME','DB_USER','DB_PASSWORD','DB_PORT','PUBLIC_BASE_URL'):
    if not os.getenv(k):
        raise SystemExit(f'FAIL: missing {k}')

print('PASS: database/public runtime configuration present')

for k in ('SPONSOR_ARTWORK_STORAGE_DIR','GAME_INTRO_STORAGE_DIR'):
    path=os.getenv(k)
    if not path:
        raise SystemExit(f'FAIL: missing {k}')
    if not os.path.isdir(path):
        raise SystemExit(f'FAIL: {k} directory does not exist')
    if not os.access(path,os.W_OK):
        raise SystemExit(f'FAIL: {k} is not writable')

print('PASS: sponsor and game intro storage writable')

live=os.getenv('BILLING_LIVE_ENABLED','').lower()
if live in {'1','true','yes','on'}: raise SystemExit('FAIL: BILLING_LIVE_ENABLED is true')
print('PASS: required runtime configuration/storage present')
print('PASS: live billing is not enabled')
PY2
fi
echo 'PRE-DEPLOY HUMAN CHECKLIST'
echo '[ ] Record exact M19-I release commit SHA'
echo '[ ] Confirm Render deploy target is that exact SHA'
echo '[ ] Verify APP_ENV=production and production HTTPS PUBLIC_BASE_URL'
echo '[ ] Verify sponsor and intro artwork persistent storage mounts'
echo '[ ] Verify BILLING_LIVE_ENABLED=false'
echo '[ ] Create/verify recoverable PostgreSQL backup/snapshot'
echo '[ ] Capture PRE baseline with production_m19i_baseline.sh pre'
echo 'M19-I PRODUCTION PREFLIGHT: PASS (automated checks)'
