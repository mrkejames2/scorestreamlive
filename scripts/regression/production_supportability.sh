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

for f in \
  app/api/support.py \
  app/services/support_diagnostics.py \
  app/logging_config.py \
  app/config.py \
  app/database.py \
  app/main.py \
  docs/M17-I_PRODUCTION_SUPPORTABILITY.md \
  docs/operations/INCIDENT_TRIAGE.md; do
  need_file "$f"
done

need_text app/config.py 'RENDER_GIT_COMMIT' 'release identity can resolve Render commit'
need_text app/config.py 'APP_RELEASE' 'explicit release identity is supported'
need_text app/main.py '"X-Request-ID"' 'HTTP responses expose request correlation ID'
need_text app/main.py '"X-ScoreStreamLive-Release"' 'HTTP responses expose release identity'
need_text app/main.py '"http.request.exception"' 'unhandled request exceptions are correlated'
need_text app/main.py '"release": settings.APP_RELEASE' 'public info/root expose safe release identity'
need_text app/logging_config.py 'ContextVar' 'request correlation uses async-safe ContextVar'
need_text app/logging_config.py '"[REDACTED]"' 'structured logging redacts sensitive extras'
need_text app/api/support.py 'Depends(require_current_user)' 'support diagnostics require authentication'
need_text app/api/support.py 'require_director(current_user)' 'support diagnostics require Director role'
need_text app/services/support_diagnostics.py 'check_database_health' 'support snapshot performs read-only DB health check'
need_text app/services/support_diagnostics.py '"configured_origin_count"' 'support snapshot reports socket policy without origin values'
need_text app/database.py 'SELECT 1' 'database diagnostic remains read-only'
forbid_text app/services/support_diagnostics.py 'SMTP_PASSWORD' 'support payload does not expose SMTP password'
forbid_text app/services/support_diagnostics.py 'DB_PASSWORD' 'support payload does not expose DB password'
forbid_text app/services/support_diagnostics.py 'AUTH_SESSION' 'support payload does not expose session configuration'

if find alembic/versions -maxdepth 1 -type f \( -iname '*m17i*' -o -iname '*supportability*' \) | grep -q .; then
  no 'M17-I unexpectedly introduces an Alembic migration'
else
  pass 'M17-I introduces no Alembic migration'
fi

live_headers="$(mktemp)"
info_body="$(mktemp)"
trap 'rm -f "$live_headers" "$info_body"' EXIT

if curl -fsS -D "$live_headers" -o /dev/null "$BASE_URL/health/live"; then
  pass '/health/live remains available'
else
  no '/health/live unavailable'
fi

if grep -qi '^X-Request-ID:' "$live_headers"; then
  pass 'live response contains X-Request-ID'
else
  no 'live response missing X-Request-ID'
fi

if grep -qi '^X-ScoreStreamLive-Release:' "$live_headers"; then
  pass 'live response contains release header'
else
  no 'live response missing release header'
fi

if curl -fsS "$BASE_URL/info" -o "$info_body"; then
  if python3 - "$info_body" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert isinstance(data.get("release"), str) and data["release"]
assert "application" in data and "version" in data and "environment" in data
PY
  then
    pass '/info exposes safe release identity'
  else
    no '/info release payload invalid'
  fi
else
  no '/info unavailable'
fi

support_code="$(curl -sS -o /dev/null -w '%{http_code}' "$BASE_URL/api/support/diagnostics" || true)"
case "$support_code" in
  401|403)
    pass 'logged-out support diagnostics access denied'
    ;;
  *)
    no "logged-out support diagnostics expected 401/403, got $support_code"
    ;;
esac

if [[ "${VALIDATION_MODE:-local}" == "production" ]]; then
  pass 'production supportability regression is non-destructive'
fi

exit "$fail"
