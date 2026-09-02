"""Socket.IO server, game-room subscription, and scoped event delivery."""

import logging
import uuid
from datetime import datetime, timezone
from http.cookies import SimpleCookie
from typing import Literal
from urllib.parse import urlparse

import socketio

from app.auth.authorization import can_operate_game
from app.config import settings
from app.database import AsyncSessionLocal
from app.models.game import Game
from app.services.auth_service import resolve_session_user

logger = logging.getLogger("app")

# Environment-aware CORS: empty string defaults to same-origin only
_raw = settings.SOCKET_CORS_ORIGINS
if _raw == "*":
    cors_origins = "*"
elif _raw:
    cors_origins = [o.strip() for o in _raw.split(",") if o.strip()]
else:
    cors_origins = []  # same-origin only

MATCH_DAY_EVENTS = {
    "game:created",
    "game:updated",
    "game:score_updated",
    "scoring_event:created",
    "scoring_event:updated",
    "scoring_event:corrected",
    "scoring_event:deleted",
    "game:lifecycle_updated",
    "lifecycle:updated",
    "game:phase_updated",
    "game:clock_updated",
    "clock:updated",
}


class GameScopedAsyncServer(socketio.AsyncServer):
    """Prevent known match-day events from falling back to global broadcast."""

    async def emit(
        self,
        event,
        data=None,
        to=None,
        room=None,
        skip_sid=None,
        namespace=None,
        callback=None,
        ignore_queue=False,
    ):
        if room is None and to is None and event in MATCH_DAY_EVENTS:
            payload = data if isinstance(data, dict) else {}
            game_id = payload.get("game_id") or payload.get("id")
            if not game_id:
                logger.error(
                    "Blocked unscoped match-day Socket.IO event — event=%s",
                    event,
                    extra={"event": "socket.match_event.blocked", "event_name": event},
                )
                return None

            # Existing service/API emit call sites remain valid, but delivery is
            # now server-enforced to this Game. Public and control audiences are
            # deliberately separate rooms.
            await super().emit(
                event,
                data,
                room=game_room(game_id, "overlay"),
                skip_sid=skip_sid,
                namespace=namespace,
                callback=callback,
                ignore_queue=ignore_queue,
            )
            return await super().emit(
                event,
                data,
                room=game_room(game_id, "control"),
                skip_sid=skip_sid,
                namespace=namespace,
                callback=callback,
                ignore_queue=ignore_queue,
            )

        return await super().emit(
            event,
            data,
            to=to,
            room=room,
            skip_sid=skip_sid,
            namespace=namespace,
            callback=callback,
            ignore_queue=ignore_queue,
        )


SocketAudience = Literal["overlay", "control"]


def game_room(game_id: uuid.UUID | str, audience: SocketAudience) -> str:
    """Return the deterministic audience-specific room for one Game."""
    suffix = "public" if audience == "overlay" else "control"
    return f"game:{game_id}:{suffix}"


sio = GameScopedAsyncServer(
    async_mode="asgi",
    path="/socket.io",
    cors_allowed_origins=cors_origins,
    logger=False,
    engineio_logger=False,
)


async def emit_game_event(
    event_name: str,
    payload: dict,
    game_id: uuid.UUID | str,
) -> None:
    """Deliver a public match-state notification only to this Game's rooms.

    Current match-day events are safe for the public Overlay. Control clients
    receive the same notification stream, but only after authorization. The
    two rooms keep public and privileged subscriptions distinct so future
    control-only events cannot accidentally become public.
    """
    await sio.emit(
        event_name,
        payload,
        room=game_room(game_id, "overlay"),
    )
    await sio.emit(
        event_name,
        payload,
        room=game_room(game_id, "control"),
    )



def _header_from_environ(environ: dict, header_name: str) -> str:
    """Read a handshake header from Engine.IO ASGI/WSGI environ shapes."""
    direct = environ.get(f"HTTP_{header_name.upper().replace('-', '_')}")
    if direct:
        return str(direct)

    scope = environ.get("asgi.scope") or {}
    target = header_name.lower()
    for raw_name, raw_value in scope.get("headers", []):
        try:
            name = raw_name.decode("latin-1").lower()
            value = raw_value.decode("latin-1")
        except AttributeError:
            name = str(raw_name).lower()
            value = str(raw_value)
        if name == target:
            return value
    return ""


def _control_game_id_from_environ(environ: dict) -> str | None:
    """Infer the visible Control Center game from the same-origin Referer.

    This is only a compatibility hint for pre-HF1 cached clients. The value
    never grants access: _subscribe_game still resolves the authenticated
    session and enforces can_operate_game() before room membership.
    """
    referer = _header_from_environ(environ, "referer")
    if not referer:
        return None

    try:
        path = urlparse(referer).path.rstrip("/")
    except ValueError:
        return None

    prefix = "/control/games/"
    if not path.startswith(prefix):
        return None

    candidate = path[len(prefix):]
    if "/" in candidate or not candidate:
        return None

    try:
        return str(uuid.UUID(candidate))
    except (TypeError, ValueError, AttributeError):
        return None

def _cookie_header(environ: dict) -> str:
    """Read the Engine.IO handshake Cookie header for ASGI or WSGI shapes."""
    direct = environ.get("HTTP_COOKIE")
    if direct:
        return str(direct)

    scope = environ.get("asgi.scope") or {}
    for raw_name, raw_value in scope.get("headers", []):
        try:
            name = raw_name.decode("latin-1").lower()
            value = raw_value.decode("latin-1")
        except AttributeError:
            name = str(raw_name).lower()
            value = str(raw_value)
        if name == "cookie":
            return value
    return ""


def _session_token_from_environ(environ: dict) -> str | None:
    raw_cookie = _cookie_header(environ)
    if not raw_cookie:
        return None

    parsed = SimpleCookie()
    try:
        parsed.load(raw_cookie)
    except Exception:
        return None

    morsel = parsed.get(settings.AUTH_SESSION_COOKIE_NAME)
    return morsel.value if morsel is not None else None


async def _leave_previous_game_room(sid: str, session: dict) -> None:
    previous_room = session.get("game_room")
    if previous_room:
        await sio.leave_room(sid, previous_room)


@sio.event
async def connect(sid, environ, auth=None):
    """Handle transport connection and optional initial Game subscription."""
    await sio.save_session(
        sid,
        {
            "auth_token": _session_token_from_environ(environ),
            "game_room": None,
            "game_id": None,
            "audience": None,
        },
    )

    logger.info(
        "Socket connected — sid=%s",
        sid,
        extra={
            "event": "socket.connected",
            "socket_id": sid,
        },
    )

    # Overlay and current Control clients can supply their game subscription in
    # the handshake so room membership exists before the browser connect
    # callback begins recovery.
    initial_subscription = None
    if isinstance(auth, dict) and auth.get("game_id"):
        initial_subscription = auth
    else:
        # HF1 compatibility path: browsers may still have the pre-M16-B
        # Control socket module cached. Those clients connect without auth or
        # game:subscribe, so infer only the visible Control game from Referer.
        # Authorization is still enforced by _subscribe_game; Referer never
        # grants room access by itself.
        control_game_id = _control_game_id_from_environ(environ)
        if control_game_id:
            initial_subscription = {
                "game_id": control_game_id,
                "audience": "control",
            }

    if initial_subscription is not None:
        result = await _subscribe_game(sid, initial_subscription)
        if result.get("status") != "ok":
            logger.warning(
                "Socket initial subscription denied — sid=%s",
                sid,
                extra={
                    "event": "socket.subscription.initial_denied",
                    "socket_id": sid,
                    "audience": initial_subscription.get("audience"),
                    "game_id": str(initial_subscription.get("game_id")),
                },
            )
            return False

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


async def _subscribe_game(sid: str, data: dict) -> dict:
    """Validate and establish exactly one Game subscription for a socket."""
    try:
        game_id = uuid.UUID(str(data.get("game_id", "")))
    except (TypeError, ValueError, AttributeError):
        return {"status": "error", "reason": "invalid game"}

    audience = str(data.get("audience", ""))
    if audience not in {"overlay", "control"}:
        return {"status": "error", "reason": "invalid audience"}

    session = await sio.get_session(sid)

    async with AsyncSessionLocal() as db:
        game = await db.get(Game, game_id)
        if game is None:
            return {"status": "error", "reason": "game unavailable"}

        if audience == "control":
            user = await resolve_session_user(db, session.get("auth_token"))
            if user is None or not await can_operate_game(db, user, game):
                logger.warning(
                    "Socket control subscription denied — sid=%s game_id=%s",
                    sid,
                    game_id,
                    extra={
                        "event": "socket.subscription.denied",
                        "socket_id": sid,
                        "game_id": str(game_id),
                        "audience": audience,
                    },
                )
                return {"status": "error", "reason": "subscription denied"}

    room = game_room(game_id, audience)  # type: ignore[arg-type]

    # One Socket.IO connection represents one visible Game. Repeated subscribe
    # calls are idempotent, while a changed game/audience leaves the old room
    # first so stale subscriptions cannot accumulate.
    if session.get("game_room") != room:
        await _leave_previous_game_room(sid, session)
        await sio.enter_room(sid, room)

    session.update(
        {
            "game_room": room,
            "game_id": str(game_id),
            "audience": audience,
        }
    )
    await sio.save_session(sid, session)

    logger.info(
        "Socket game subscription active — sid=%s game_id=%s audience=%s",
        sid,
        game_id,
        audience,
        extra={
            "event": "socket.subscription.active",
            "socket_id": sid,
            "game_id": str(game_id),
            "audience": audience,
            "room": room,
        },
    )

    return {
        "status": "ok",
        "game_id": str(game_id),
        "audience": audience,
    }


@sio.on("game:subscribe")
async def handle_game_subscribe(sid, data):
    """Join one Game room after validating audience and authorization."""
    if not isinstance(data, dict):
        return {"status": "error", "reason": "invalid subscription"}
    return await _subscribe_game(sid, data)


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
    """Preserve the legacy diagnostic broadcast event used by socket tests."""
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
