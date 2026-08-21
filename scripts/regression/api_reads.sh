#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

source scripts/lib/validation.sh
validation_init || exit $?

fail=0
games_tmp="$(mktemp)"
teams_tmp="$(mktemp)"
trap 'rm -f "$games_tmp" "$teams_tmp"' EXIT

v_expect_http "/api/games" 200 || fail=1
v_expect_http "/api/teams" 200 || fail=1

if ! curl -fsS "${BASE_URL}/api/games" -o "$games_tmp"; then
  echo "FAIL could not download /api/games"
  fail=1
fi

if ! curl -fsS "${BASE_URL}/api/teams" -o "$teams_tmp"; then
  echo "FAIL could not download /api/teams"
  fail=1
fi

if [[ "$fail" -eq 0 ]]; then
  python3 - "$games_tmp" "$teams_tmp" <<'PY' || fail=1
import json
import sys
from pathlib import Path

for label, filename in (("games", sys.argv[1]), ("teams", sys.argv[2])):
    try:
        data = json.loads(Path(filename).read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"FAIL {label} response is not valid JSON: {exc}")

    if not isinstance(data, list):
        raise SystemExit(f"FAIL {label} response is not a list")

    print(f"PASS {label} collection shape ({len(data)} items)")
PY
fi

exit "$fail"
