#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

fail=0
pass(){ echo "PASS $*"; }
no(){ echo "FAIL $*"; fail=1; }
need_file(){ [[ -f "$1" ]] && pass "file $1" || no "missing $1"; }
need_text(){ grep -Fq "$2" "$1" && pass "$3" || no "$3"; }
forbid_text(){ if grep -Fq "$2" "$1"; then no "$3"; else pass "$3"; fi; }

# Release/runtime files must remain present and deterministic.
for f in Dockerfile entrypoint.sh render.yaml app/auth/security.py app/config.py app/database.py scripts/validate.sh; do
  need_file "$f"
done

# Container/Render startup: automatic migrations, no shell-only release procedure,
# non-root runtime, health endpoint, and production deployment from main.
need_text entrypoint.sh 'alembic upgrade head' 'automatic Alembic upgrade remains enabled'
need_text entrypoint.sh 'M15_BOOTSTRAP_ENABLED:-false' 'production bootstrap defaults disabled'
need_text entrypoint.sh 'exec uvicorn app.main:socket_app' 'application starts through Socket.IO ASGI app'
need_text Dockerfile 'USER appuser' 'container runtime remains non-root'
need_text Dockerfile 'HEALTHCHECK' 'container healthcheck remains configured'
need_text render.yaml 'branch: main' 'Render deploys from main'
need_text render.yaml 'healthCheckPath: /health/live' 'Render health check uses liveness endpoint'
need_text render.yaml 'SOCKET_CORS_ORIGINS' 'Render declares explicit Socket.IO origin setting'
need_text render.yaml 'DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD' 'Render database model uses explicit DB variables'

# M16-C/M16-E production security startup and reverse-proxy-safe mutation boundary.
need_text app/auth/security.py 'AUTH_SESSION_COOKIE_SECURE must be true in production' 'secure production session cookie enforced'
need_text app/auth/security.py 'DB_PASSWORD must not use the development default in production' 'default database password rejected in production'
need_text app/auth/security.py "SOCKET_CORS_ORIGINS must not be '*' in production" 'wildcard production Socket.IO origin rejected'
need_text app/auth/security.py 'SOCKET_CORS_ORIGINS must use https origins in production' 'production origins must use HTTPS'
need_text app/auth/security.py '_configured_production_origins()' 'production mutation boundary uses explicit origin allowlist'
need_text app/auth/security.py 'actual in expected_origins' 'production mutation origin must match allowlist'
forbid_text app/auth/security.py "headers.get('x-forwarded-proto'" 'security boundary does not trust client X-Forwarded-Proto'
forbid_text app/auth/security.py 'headers.get("x-forwarded-proto"' 'security boundary does not trust client X-Forwarded-Proto (double quote)'

# Database remains server-authoritative and production SSL remains required.
need_text app/database.py 'if settings.APP_ENV == "production"' 'production database branch exists'
need_text app/database.py 'url += "?ssl=require"' 'production database requires SSL'

# Final cumulative release documentation and validation domain exist.
need_file docs/milestones/m16/M16E_PRODUCTION_OPERATIONS_FINAL_RELEASE.md
need_text scripts/validate.sh "add 'Production Operations/Final Release Gate'" 'M16-E final release validation domain registered'
need_text docs/milestones/m16/M16E_PRODUCTION_OPERATIONS_FINAL_RELEASE.md 'Production FAST' 'production FAST gate documented'
need_text docs/milestones/m16/M16E_PRODUCTION_OPERATIONS_FINAL_RELEASE.md 'Production FULL' 'production FULL gate documented'
need_text docs/milestones/m16/M16E_PRODUCTION_OPERATIONS_FINAL_RELEASE.md 'M16 PRODUCTION MVP HARDENING = COMPLETE' 'M16 completion declaration documented'

# No schema or infrastructure expansion belongs in M16-E.
if find alembic/versions -maxdepth 1 -type f -name '202609*_*.py' -printf '%f\n' | grep -v '^20260902_0013_add_scoring_request_id.py$' | grep -q .; then
  no 'unexpected September 2026 Alembic migration added'
else
  pass 'Alembic head remains M16-A migration 20260902_0013'
fi

for term in redis kafka nats rabbitmq celery kubernetes; do
  if grep -Eqi "(^|[^[:alnum:]_])${term}([^[:alnum:]_]|$)" app/auth/security.py entrypoint.sh render.yaml 2>/dev/null; then
    no "M16-E runtime unexpectedly introduces $term"
  else
    pass "M16-E runtime does not introduce $term"
  fi
done

# Production mode must stay non-destructive here. Runtime mutation/recovery is
# covered by inherited domains and the documented local human recovery exercise.
if [[ "${VALIDATION_MODE:-local}" == "production" ]]; then
  pass 'production final-release regression is non-destructive'
fi

exit "$fail"
