#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

DEST_DIR="static/vendor"
DEST_FILE="${DEST_DIR}/socket.io.min.js"

# Socket.IO 4.x uses Engine.IO protocol 4 and is compatible with the
# existing ScoreStreamLive python-socketio M3-M9 event transport.
SOCKET_IO_VERSION="${SOCKET_IO_VERSION:-4.8.1}"

URL="https://cdn.socket.io/${SOCKET_IO_VERSION}/socket.io.min.js"

mkdir -p "$DEST_DIR"

echo "========================================"
echo "ScoreStreamLive M10-B Socket.IO Client"
echo "Version: ${SOCKET_IO_VERSION}"
echo "========================================"

echo "[INFO] Downloading browser client..."
curl -fL --retry 3 --retry-delay 1 \
    "$URL" \
    -o "$DEST_FILE"

if [ ! -s "$DEST_FILE" ]; then
    echo "[FAIL] Downloaded Socket.IO client is empty."
    exit 1
fi

if ! grep -q "Socket.IO" "$DEST_FILE" && ! grep -q "socket.io" "$DEST_FILE"; then
    echo "[WARN] Could not identify expected Socket.IO marker in vendor file."
fi

echo "[PASS] Installed:"
echo "       ${DEST_FILE}"
echo ""
echo "Runtime URL:"
echo "       /static/vendor/socket.io.min.js"
