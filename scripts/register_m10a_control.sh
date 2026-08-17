#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAIN_FILE="${PROJECT_ROOT}/app/main.py"
BACKUP_FILE="${PROJECT_ROOT}/app/main.py.pre_m10a"

IMPORT_LINE='from app.api.control import router as control_router'
INCLUDE_LINE='app.include_router(control_router)'

echo "========================================"
echo "ScoreStreamLive M10-A Router Registration"
echo "========================================"

if [ ! -f "$MAIN_FILE" ]; then
    echo "[FAIL] app/main.py was not found:"
    echo "       $MAIN_FILE"
    exit 1
fi

if [ ! -f "${PROJECT_ROOT}/app/api/control.py" ]; then
    echo "[FAIL] app/api/control.py was not found."
    echo ""
    echo "Make sure the M10-A package was copied into the project first."
    exit 1
fi

echo "[INFO] main.py:"
echo "       $MAIN_FILE"

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

if [ ! -f "$BACKUP_FILE" ]; then
    cp "$MAIN_FILE" "$BACKUP_FILE"

    echo "[PASS] Backup created:"
    echo "       app/main.py.pre_m10a"
else
    echo "[INFO] Backup already exists:"
    echo "       app/main.py.pre_m10a"
fi

# ------------------------------------------------------------
# Register import
# ------------------------------------------------------------

if grep -Fq "$IMPORT_LINE" "$MAIN_FILE"; then
    echo "[PASS] control_router import already registered"
else
    python3 - "$MAIN_FILE" "$IMPORT_LINE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
import_line = sys.argv[2]

text = path.read_text()

lines = text.splitlines()

insert_index = None

# Prefer to place the new import immediately after the final
# "from app.api..." import.
for index, line in enumerate(lines):
    stripped = line.strip()

    if (
        stripped.startswith("from app.api.")
        or stripped.startswith("import app.api.")
    ):
        insert_index = index + 1

# If no app.api import exists, place it after the final import line.
if insert_index is None:
    for index, line in enumerate(lines):
        stripped = line.strip()

        if (
            stripped.startswith("import ")
            or stripped.startswith("from ")
        ):
            insert_index = index + 1

if insert_index is None:
    insert_index = 0

lines.insert(
    insert_index,
    import_line,
)

path.write_text(
    "\n".join(lines) + "\n"
)
PY

    echo "[PASS] Added control_router import"
fi

# ------------------------------------------------------------
# Register router
# ------------------------------------------------------------

if grep -Fq "$INCLUDE_LINE" "$MAIN_FILE"; then
    echo "[PASS] control_router already included"
else
    python3 - "$MAIN_FILE" "$INCLUDE_LINE" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
include_line = sys.argv[2]

text = path.read_text()

lines = text.splitlines()

include_indexes = []

for index, line in enumerate(lines):
    if "app.include_router(" in line:
        include_indexes.append(index)

if not include_indexes:
    print(
        "[FAIL] No existing app.include_router(...) calls found.",
        file=sys.stderr,
    )
    print(
        "       main.py was NOT modified for router registration.",
        file=sys.stderr,
    )
    sys.exit(2)

insert_index = include_indexes[-1] + 1

lines.insert(
    insert_index,
    include_line,
)

path.write_text(
    "\n".join(lines) + "\n"
)
PY

    echo "[PASS] Added app.include_router(control_router)"
fi

# ------------------------------------------------------------
# Python syntax validation
# ------------------------------------------------------------

echo ""
echo "Checking Python syntax..."

python3 -m py_compile "$MAIN_FILE"

echo "[PASS] app/main.py Python syntax valid"

# ------------------------------------------------------------
# Show exact registration
# ------------------------------------------------------------

echo ""
echo "M10-A registration now present:"
echo "----------------------------------------"

grep -n \
    -E 'control_router|include_router' \
    "$MAIN_FILE"

echo "----------------------------------------"

echo ""
echo "========================================"
echo "M10-A ROUTER REGISTRATION COMPLETE"
echo "========================================"
echo ""
echo "Next:"
echo ""
echo "sudo docker compose down"
echo "sudo docker compose up --build -d"
echo "sudo docker compose ps"
echo ""