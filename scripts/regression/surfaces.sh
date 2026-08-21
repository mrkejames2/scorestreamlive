#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
source scripts/lib/validation.sh; validation_init || exit $?
f=0
v_expect_http /games 200 || f=1
v_expect_http /teams 200 || f=1
v_expect_contains_url /games /static/js/games/index.js || f=1
exit "$f"
