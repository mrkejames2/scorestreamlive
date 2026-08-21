#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
source scripts/lib/validation.sh; validation_init || exit $?
[[ "$VALIDATION_MODE" == local ]] || { echo 'SKIP recovery: local-only'; exit 0; }
f=0
echo 'Restarting application container...'
docker compose restart app || exit 1
v_wait_http /health/ready 45 2 || f=1
echo 'Restarting PostgreSQL container...'
docker compose restart postgres || exit 1
ready=0
for _ in {1..45}; do docker compose exec -T postgres pg_isready >/dev/null 2>&1 && { ready=1; break; }; sleep 2; done
[[ "$ready" == 1 ]] && echo 'PASS PostgreSQL ready after restart' || { echo 'FAIL PostgreSQL did not become ready'; f=1; }
v_wait_http /health/ready 45 2 || f=1
v_expect_http /api/games 200 || f=1
v_expect_http /api/teams 200 || f=1
exit "$f"
