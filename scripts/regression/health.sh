#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
source scripts/lib/validation.sh; validation_init || exit $?
f=0
v_expect_http /health/live 200 || f=1
v_expect_http /health/ready 200 || f=1
v_expect_http /info 200 || f=1
exit "$f"
