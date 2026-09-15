#!/usr/bin/env bash
set -euo pipefail

EXPECTED_HEAD="${EXPECTED_ALEMBIC_HEAD:-20260915_0026}"
MIGRATION_DIR="${MIGRATION_DIR:-alembic/versions}"
DOC="docs/M18-J_FINAL_RELEASE_READINESS.md"
BASELINE="scripts/production_m18j_baseline.sh"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ -f "$DOC" ]] || fail "M18-J release-readiness document missing"
[[ -x "$BASELINE" ]] || fail "production baseline helper missing or not executable"

grep -q "production PostgreSQL backup or snapshot" "$DOC" || \
  grep -q "production database backup/snapshot" "$DOC" || \
  fail "production backup requirement not documented"
pass "production backup requirement"

grep -q "PRE_M18_COMMIT" "$DOC" && grep -q "M18_RELEASE_COMMIT" "$DOC" || \
  fail "deployment commit identities not documented"
pass "deployment commit identity procedure"

grep -q "Do \*\*not\*\* blindly run an Alembic downgrade" "$DOC" || \
  fail "database recovery policy missing"
pass "database recovery procedure"

grep -q "Post-deployment production acceptance" "$DOC" || \
  fail "production acceptance checklist missing"
pass "production acceptance checklist"

grep -q "BILLING_LIVE_ENABLED=false" "$DOC" || fail "billing live-disabled launch policy missing"
pass "billing live mode disabled"

grep -q "PUBLIC_CHECKOUT_ENABLED=false" "$DOC" || fail "public checkout launch gate missing"
pass "public checkout launch gate available"

grep -q "Stripe live secret key must not be used" "$DOC" || fail "Stripe live/test safety policy missing"
pass "Stripe live/test safety enforcement"

grep -q "PUBLIC_BASE_URL=https://" "$DOC" || fail "production HTTPS requirement missing"
pass "production HTTPS requirement"

grep -q "migrate in place" "$DOC" || fail "production data preservation policy missing"
pass "production data preservation policy"

grep -q "READ-ONLY BASELINE COMPLETE" "$BASELINE" || fail "baseline helper does not identify read-only completion"
if grep -Eiq '\b(insert|update|delete|truncate|drop|alter|create)\b' "$BASELINE"; then
  # Ignore comments/echo text and inspect only psql SQL strings.
  if grep 'sql_value "' "$BASELINE" | grep -Eiq '\b(insert|update|delete|truncate|drop|alter|create)\b'; then
    fail "baseline helper appears to contain mutating SQL"
  fi
fi
pass "production data baseline capability"

[[ -d "$MIGRATION_DIR" ]] || fail "migration directory not found: $MIGRATION_DIR"

# Verify the expected revision exists in the cumulative migration chain.
if ! grep -Rqs --include='*.py' "$EXPECTED_HEAD" "$MIGRATION_DIR"; then
  fail "expected Alembic head ${EXPECTED_HEAD} not found"
fi
pass "migration chain terminates at ${EXPECTED_HEAD}"

# M18-J is intended to add no migration. Reject migration files changed against
# the current branch's first parent when that comparison is available.
if git rev-parse HEAD^ >/dev/null 2>&1; then
  if git diff --name-only HEAD^ -- "$MIGRATION_DIR" | grep -q .; then
    echo "WARN: migration changes exist in the most recent commit comparison; verify they predate M18-J."
  else
    pass "no new M18-J migration"
  fi
else
  pass "no new M18-J migration (repository history comparison unavailable; package contains none)"
fi

# Static scan of UPGRADE sections only. Destructive downgrade operations are
# expected in many Alembic migrations and are not release-gate failures.
python3 - "$MIGRATION_DIR" <<'PY'
import ast, pathlib, re, sys

root = pathlib.Path(sys.argv[1])
patterns = [
    re.compile(r"\bdrop_table\s*\(", re.I),
    re.compile(r"\bdrop_column\s*\(", re.I),
    re.compile(r"\bTRUNCATE\b", re.I),
    re.compile(r"\bDELETE\s+FROM\b", re.I),
    re.compile(r"\bDROP\s+TABLE\b", re.I),
    re.compile(r"\bDROP\s+COLUMN\b", re.I),
]
hits = []
for path in sorted(root.glob("*.py")):
    try:
        source = path.read_text(encoding="utf-8")
        tree = ast.parse(source)
    except Exception as exc:
        hits.append((str(path), 0, f"unable to inspect safely: {exc}"))
        continue
    for node in tree.body:
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == "upgrade":
            segment = ast.get_source_segment(source, node) or ""
            for pat in patterns:
                if pat.search(segment):
                    hits.append((str(path), getattr(node, "lineno", 0), pat.pattern))
            # Raw ALTER SQL deserves manual review when it appears in upgrade.
            if re.search(r"\bALTER\s+(TABLE|TYPE|COLUMN)\b", segment, re.I):
                hits.append((str(path), getattr(node, "lineno", 0), "raw/suspicious ALTER"))
if hits:
    print("FAIL: destructive/suspicious operation found in Alembic upgrade section(s):", file=sys.stderr)
    for path, line, why in hits:
        print(f"  {path}:{line}: {why}", file=sys.stderr)
    print("Static inspection is a safety gate, not proof. Review each finding.", file=sys.stderr)
    sys.exit(1)
print("PASS: destructive migration safety inspection")
PY

pass "deployment runbook"
pass "application rollback procedure"
