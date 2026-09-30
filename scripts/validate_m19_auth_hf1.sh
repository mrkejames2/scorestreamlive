#!/usr/bin/env bash
set -euo pipefail
python3 -m py_compile app/auth/authorization.py app/api/teams.py app/api/sponsors.py app/api/game_sponsors.py
git diff --check
grep -q '_require_manager_club' app/api/sponsors.py
grep -q 'Director or Manager access required' app/api/game_sponsors.py
echo "M19 AUTH-HF1 static validation: PASS"
