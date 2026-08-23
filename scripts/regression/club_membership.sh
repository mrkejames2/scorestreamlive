#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
source scripts/lib/validation.sh
validation_init || exit $?
fail=0
check(){ local d="$1" p="$2" f="$3"; if grep -Fq "$p" "$f"; then echo "PASS $d"; else echo "FAIL $d"; fail=1; fi; }
if [[ "$VALIDATION_MODE" == "local" ]]; then
  check "Club model" 'class Club(Base):' app/models/club.py
  check "single Club membership" 'club_id: Mapped[Optional[uuid.UUID]]' app/models/user.py
  check "Club role field" 'club_role: Mapped[Optional[str]]' app/models/user.py
  check "DIRECTOR role" 'DIRECTOR = "DIRECTOR"' app/auth/roles.py
  check "MANAGER role" 'MANAGER = "MANAGER"' app/auth/roles.py
  check "OPERATOR role" 'OPERATOR = "OPERATOR"' app/auth/roles.py
  check "bootstrap Club" 'async def bootstrap()' app/cli/bootstrap_club.py
  check "M15-B migration" 'revision = "20260824_0011"' alembic/versions/20260824_0011_add_clubs_and_user_membership.py
  check "current Club API" '@router.get("/current"' app/api/clubs.py
fi
status="$(curl -sS -o /dev/null -w '%{http_code}' "${BASE_URL}/api/clubs/current" || true)"
if [[ "$status" == "401" ]]; then echo "PASS unauthenticated current Club rejected"; else echo "FAIL unauthenticated current Club expected 401 got ${status}"; fail=1; fi
curl -fsS "${BASE_URL}/games" >/dev/null || { echo "FAIL existing /games surface"; fail=1; }
curl -fsS "${BASE_URL}/teams" >/dev/null || { echo "FAIL existing /teams surface"; fail=1; }
exit "$fail"
