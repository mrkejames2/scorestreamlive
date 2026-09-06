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

# M17-J is deliberately documentation + validation only.
for f in \
  README.md \
  docs/ARCHITECTURE.md \
  docs/CURRENT_MILESTONE_STATUS.md \
  docs/DEPLOYMENT.md \
  docs/M17-J_CUSTOMER_READINESS_RELEASE_GATE.md \
  docs/operations/PRODUCTION_RELEASE_CHECKLIST.md \
  docs/operations/INCIDENT_TRIAGE.md \
  scripts/regression/customer_readiness_release_gate.sh \
  scripts/regression/production_supportability.sh \
  scripts/validate.sh \
  scripts/validate_m17j.sh \
  render.yaml \
  entrypoint.sh \
  Dockerfile; do
  need_file "$f"
done

# Current repository documentation must describe the active product/release.
need_text README.md '# ScoreStreamLive' 'README identifies ScoreStreamLive'
need_text README.md 'M17-J' 'README identifies final M17 release gate'
need_text docs/ARCHITECTURE.md 'PostgreSQL = authoritative persistent state' 'architecture preserves PostgreSQL authority'
need_text docs/ARCHITECTURE.md 'Socket.IO  = committed-state notification transport' 'architecture preserves Socket.IO transport role'
need_text docs/CURRENT_MILESTONE_STATUS.md 'M17-J  Customer Readiness & Production Release Gate' 'milestone status identifies M17-J'
need_text docs/CURRENT_MILESTONE_STATUS.md 'M17 PRODUCTION COMPLETE = DECLARED' 'production completion is declared'
need_text docs/DEPLOYMENT.md 'production Human Acceptance' 'deployment guide includes production Human Acceptance'
need_text docs/M17-J_CUSTOMER_READINESS_RELEASE_GATE.md 'Production validation must be non-destructive.' 'M17-J requires non-destructive production validation'
need_text docs/operations/PRODUCTION_RELEASE_CHECKLIST.md 'M15_BOOTSTRAP_ENABLED=false' 'production checklist requires bootstrap disabled'

# The current top-level docs must no longer present obsolete milestones as current.
forbid_text README.md 'M10-F Regression Cleanup' 'README is no longer an M10-F repair README'
forbid_text docs/CURRENT_MILESTONE_STATUS.md 'STATUS: NEXT / NOT STARTED' 'status doc no longer marks old milestone as next'
forbid_text docs/DEPLOYMENT.md 'M13 Production Validation' 'deployment guide is no longer centered on M13'

# All cumulative M17 domains must remain registered and M17-J must be domain 35.
need_text scripts/validate.sh "add 'Club User Administration'" 'M17-A domain registered'
need_text scripts/validate.sh "add 'Team & Game Lifecycle'" 'M17-B domain registered'
need_text scripts/validate.sh "add 'Post-Game Summary & Broadcast Scene'" 'M17-C domain registered'
need_text scripts/validate.sh "add 'User Invitation & Account Activation'" 'M17-D domain registered'
need_text scripts/validate.sh "add 'Account Recovery & User Lifecycle'" 'M17-E domain registered'
need_text scripts/validate.sh "add 'Match-Day Workflow & Operator Polish'" 'M17-F domain registered'
need_text scripts/validate.sh "add 'Compact Broadcast Overlay & Brand Integration'" 'M17-G domain registered'
need_text scripts/validate.sh "add 'Cohesive Product Theme & UI Consistency'" 'M17-H domain registered'
need_text scripts/validate.sh "add 'Production Supportability'" 'M17-I domain registered'
need_text scripts/validate.sh "add 'Customer Readiness & Production Release Gate'" 'M17-J domain registered'

domain_count="$(grep -Ec "^add( | ')[^']|^add [A-Za-z]" scripts/validate.sh || true)"
# Stable explicit count: only count add registrations before the conditional Recovery domain.
domain_count="$(awk '/^if \[\[ "\$VALIDATION_SCOPE"/{exit} /^add /{n++} END{print n+0}' scripts/validate.sh)"
if [[ "$domain_count" == "35" ]]; then
  pass 'cumulative non-release validation contains 35 domains'
else
  no "expected 35 cumulative domains, found $domain_count"
fi

# Deployment contracts remain unchanged from the accepted production baseline.
need_text render.yaml 'branch: main' 'Render deploys main'
need_text render.yaml 'healthCheckPath: /health/live' 'Render health check remains liveness'
need_text render.yaml 'APP_ENV' 'Render declares application environment'
need_text render.yaml 'SOCKET_CORS_ORIGINS' 'Render declares explicit Socket.IO origins'
need_text entrypoint.sh 'alembic upgrade head' 'startup still applies Alembic migrations'
need_text entrypoint.sh 'M15_BOOTSTRAP_ENABLED:-false' 'bootstrap remains disabled by default'
need_text Dockerfile 'USER appuser' 'runtime remains non-root'

# Final gate adds no release-specific schema migration or distributed runtime.
if find alembic/versions -maxdepth 1 -type f \( -iname '*m17j*' -o -iname '*customer*readiness*' -o -iname '*release*gate*' \) | grep -q .; then
  no 'M17-J unexpectedly introduces an Alembic migration'
else
  pass 'M17-J introduces no Alembic migration'
fi

for term in redis kafka nats rabbitmq celery kubernetes; do
  if grep -Eqi "(^|[^[:alnum:]_])${term}([^[:alnum:]_]|$)" \
      render.yaml entrypoint.sh Dockerfile app 2>/dev/null; then
    no "M17-J runtime unexpectedly introduces $term"
  else
    pass "M17-J runtime does not introduce $term"
  fi
done

# Safe live checks. No customer data is created or mutated here.
live_headers="$(mktemp)"
ready_body="$(mktemp)"
info_body="$(mktemp)"
trap 'rm -f "$live_headers" "$ready_body" "$info_body"' EXIT

if curl -fsS -D "$live_headers" -o /dev/null "$BASE_URL/health/live"; then
  pass '/health/live available'
else
  no '/health/live unavailable'
fi

if curl -fsS "$BASE_URL/health/ready" -o "$ready_body"; then
  pass '/health/ready available'
else
  no '/health/ready unavailable'
fi

if curl -fsS "$BASE_URL/info" -o "$info_body"; then
  if python3 - "$info_body" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
for key in ("application", "version", "environment", "release"):
    assert key in data
assert isinstance(data["release"], str) and data["release"]
PY
  then
    pass '/info exposes release identity'
  else
    no '/info payload invalid'
  fi
else
  no '/info unavailable'
fi

if grep -qi '^X-Request-ID:' "$live_headers"; then
  pass 'normal response exposes request correlation ID'
else
  no 'normal response missing request correlation ID'
fi

if grep -qi '^X-ScoreStreamLive-Release:' "$live_headers"; then
  pass 'normal response exposes release identity header'
else
  no 'normal response missing release identity header'
fi

support_code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/api/support/diagnostics" || true)"
case "$support_code" in
  401|403)
    pass 'logged-out support diagnostics remain denied'
    ;;
  *)
    no "logged-out support diagnostics expected 401/403, got $support_code"
    ;;
esac

if [[ "${VALIDATION_MODE:-local}" == "production" ]]; then
  pass 'production customer-readiness release gate is non-destructive'
fi

exit "$fail"
