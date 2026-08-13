#!/usr/bin/env python3
"""Socket.IO diagnostic tool for ScoreStreamLive."""

import sys
import socketio
import time
import json

URL = sys.argv[1] if len(sys.argv) > 1 else "http://192.168.12.133:8000"
print(f"Testing Socket.IO against: {URL}")
print("=" * 50)

sio = socketio.Client(logger=True, engineio_logger=True)

@sio.event
def connect():
    print(f"\n[OK] Connected — sid={sio.sid}")

@sio.event
def disconnect():
    print("[WARN] Disconnected")

@sio.on("connection:ready")
def on_ready(data):
    print(f"[OK] connection:ready — {json.dumps(data)}")

@sio.on("server:pong")
def on_pong(data):
    print(f"[OK] server:pong — {json.dumps(data)}")

@sio.on("player:created")
def on_player_created(data):
    print(f"[OK] player:created — {json.dumps(data)}")

@sio.on("roster:updated")
def on_roster_updated(data):
    print(f"[OK] roster:updated — {json.dumps(data)}")

@sio.on("test:broadcast")
def on_test_broadcast(data):
    print(f"[OK] test:broadcast — {json.dumps(data)}")

# Try 1: Default transports (websocket first, fallback to polling)
print("\n--- Attempt 1: Default transports ---")
try:
    sio.connect(URL, wait_timeout=10)
    time.sleep(1)
    sio.emit("client:ping", {"timestamp": int(time.time() * 1000)})
    time.sleep(2)
    sio.disconnect()
except Exception as e:
    print(f"[FAIL] {e}")

# Try 2: Force polling only
print("\n--- Attempt 2: Force polling transport ---")
sio2 = socketio.Client(logger=True, engineio_logger=True)

@sio2.event
def connect2():
    print(f"[OK] Connected (polling) — sid={sio2.sid}")

@sio2.event
def disconnect2():
    print("[WARN] Disconnected (polling)")

@sio2.on("connection:ready")
def on_ready2(data):
    print(f"[OK] connection:ready (polling) — {json.dumps(data)}")

try:
    sio2.connect(URL, transports=["polling"], wait_timeout=10)
    time.sleep(1)
    sio2.emit("client:ping", {"timestamp": int(time.time() * 1000)})
    time.sleep(2)
    sio2.disconnect()
except Exception as e:
    print(f"[FAIL] {e}")

# Try 3: Check HTTP endpoint directly
print("\n--- Attempt 3: HTTP health check ---")
import urllib.request
try:
    resp = urllib.request.urlopen(f"{URL}/health/ready", timeout=10)
    print(f"[OK] /health/ready — {resp.status}")
except Exception as e:
    print(f"[FAIL] /health/ready — {e}")

try:
    resp = urllib.request.urlopen(f"{URL}/socket.io/", timeout=10)
    print(f"[OK] /socket.io/ — {resp.status}")
    print(f"       Body: {resp.read(200).decode()}")
except Exception as e:
    print(f"[FAIL] /socket.io/ — {e}")

print("\n" + "=" * 50)
print("Diagnostic complete.")
