#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"; cd "$ROOT"
source scripts/lib/validation.sh; validation_init || exit $?
f=0
v_expect_file_contains app/services/game_lifecycle_service.py 'await db.commit()' || f=1
v_expect_file_contains app/services/game_lifecycle_service.py 'return committed_lifecycle, clock_state' || f=1
v_expect_file_contains app/services/scoring_service.py 'await db.commit()' || f=1
v_expect_file_contains docs/CLOCK.md 'clock:tick' || f=1
if grep -Fq 'update(Game)' app/services/game_lifecycle_service.py; then echo 'FAIL lifecycle service mutates Game row directly'; f=1; else echo 'PASS lifecycle remains separate from Game row mutation'; fi
exit "$f"
