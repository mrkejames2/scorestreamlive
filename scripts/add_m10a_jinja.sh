#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQ_FILE="${PROJECT_ROOT}/requirements.txt"
BACKUP_FILE="${PROJECT_ROOT}/requirements.txt.pre_m10a"

echo "========================================"
echo "ScoreStreamLive M10-A Jinja Dependency"
echo "========================================"

if [ ! -f "$REQ_FILE" ]; then
    echo "[FAIL] requirements.txt not found:"
    echo "       $REQ_FILE"
    exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
    cp "$REQ_FILE" "$BACKUP_FILE"
    echo "[PASS] Backup created:"
    echo "       requirements.txt.pre_m10a"
else
    echo "[INFO] Backup already exists:"
    echo "       requirements.txt.pre_m10a"
fi

if grep -Eiq '^[[:space:]]*jinja2([<>=!~].*)?[[:space:]]*$' "$REQ_FILE"; then
    echo "[PASS] jinja2 already present in requirements.txt"
else
    echo "" >> "$REQ_FILE"
    echo "jinja2" >> "$REQ_FILE"
    echo "[PASS] Added jinja2 to requirements.txt"
fi

echo ""
echo "Current Jinja entry:"
grep -Ein '^[[:space:]]*jinja2' "$REQ_FILE"

echo ""
echo "========================================"
echo "JINJA DEPENDENCY UPDATE COMPLETE"
echo "========================================"