"""Socket.IO server and event handlers."""

import logging
from datetime import datetime, timezone

import socketio

from app.config import settings

logger = logging.getLogger("app")

# Environment-aware CORS: empty string defaults to same-origin only
_raw = settings.SOCKET_CORS_ORIGINS
if _raw == "*":
    cors_origins = "*"
elif _raw:
    cors_origins = [o.strip() for o in _raw.split(",") if o.strip()]
else:
    cors_origins = []  # same-origin only

sio = socketio.AsyncServer(
    async_mode="asgi",
    path="/socket.io",
    cors_allowed_origins=cors_origins,
    logger=False,
    engineio_logger=False,
)


@sio.event
async def connect(sid, environ):
    """Handle client connection."""
    logger.info(
        "Socket connected — sid=%s",
        sid,
        extra={
            "event": "socket.connected",
            "socket_id": sid,
        },
    )
    await sio.emit(
        "connection:ready",
        {"socket_id": sid},
        room=sid,
    )


@sio.event
async def disconnect(sid):
    """Handle client disconnection."""
    logger.info(
        "Socket disconnected — sid=%s",
        sid,
        extra={
            "event": "socket.disconnected",
            "socket_id": sid,
        },
    )


@sio.on("client:ping")
async def handle_client_ping(sid, data):
    """Handle ping from client. Validate payload and respond with pong + ack."""
    logger.info(
        "Socket event — sid=%s event=client:ping",
        sid,
        extra={
            "event": "socket.event",
            "socket_id": sid,
            "event_name": "client:ping",
        },
    )

    if not isinstance(data, dict):
        logger.warning(
            "Invalid ping payload from sid=%s: expected dict, got %s",
            sid,
            type(data).__name__,
            extra={
                "event": "socket.error",
                "socket_id": sid,
                "error": "invalid_payload_type",
            },
        )
        return {"status": "error", "reason": "invalid payload type"}

    client_ts = data.get("timestamp")

    await sio.emit(
        "server:pong",
        {
            "timestamp": client_ts,
            "server_time": datetime.now(timezone.utc).isoformat(),
        },
        room=sid,
    )

    return {
        "status": "acknowledged",
        "server_timestamp": datetime.now(timezone.utc).isoformat(),
    }


@sio.on("test:broadcast")
async def handle_test_broadcast(sid, data):
    """Handle broadcast test event. Validate and broadcast to all clients."""
    logger.info(
        "Socket event — sid=%s event=test:broadcast",
        sid,
        extra={
            "event": "socket.event",
            "socket_id": sid,
            "event_name": "test:broadcast",
        },
    )

    if not isinstance(data, dict):
        logger.warning(
            "Invalid broadcast payload from sid=%s",
            sid,
            extra={
                "event": "socket.error",
                "socket_id": sid,
                "error": "invalid_payload_type",
            },
        )
        return {"status": "error", "reason": "invalid payload type"}

    message = data.get("message", "No message")

    await sio.emit(
        "test:broadcast",
        {
            "message": message,
            "from_socket_id": sid,
            "server_time": datetime.now(timezone.utc).isoformat(),
        },
    )

    return {"status": "ok", "broadcasted": True}