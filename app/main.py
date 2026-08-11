"""ScoreStreamLive — Milestone 3."""

import logging
import time
from contextlib import asynccontextmanager

import socketio
from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse

from app.config import settings
from app.database import check_database_connection, engine, get_safe_database_url
from app.logging_config import configure_logging
from app.sockets import sio

configure_logging(settings.LOG_LEVEL)

# Minimal HTML validation client — no build step, no framework
CLIENT_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>ScoreStreamLive — Socket.IO Validation</title>
    <style>
        body { font-family: system-ui, sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
        .status { padding: 12px; border-radius: 6px; margin: 12px 0; font-weight: 600; }
        .connected { background: #d4edda; color: #155724; }
        .disconnected { background: #f8d7da; color: #721c24; }
        .reconnecting { background: #fff3cd; color: #856404; }
        button { padding: 10px 18px; margin: 6px 4px; cursor: pointer; font-size: 14px; }
        #log { border: 1px solid #ccc; padding: 12px; height: 320px; overflow-y: auto; font-family: monospace; font-size: 12px; background: #fafafa; }
        .log-entry { margin: 3px 0; padding: 3px 0; border-bottom: 1px solid #e0e0e0; }
        .section { margin: 24px 0; }
        h1 { font-size: 22px; }
        h2 { font-size: 16px; margin-top: 24px; }
    </style>
</head>
<body>
    <h1>ScoreStreamLive — Socket.IO Validation Client</h1>

    <div id="connection-status" class="status disconnected">Disconnected</div>
    <div>Socket ID: <span id="socket-id">-</span></div>

    <div class="section">
        <h2>Controls</h2>
        <button id="btn-ping">Send Ping</button>
        <button id="btn-broadcast">Send Broadcast</button>
        <button id="btn-disconnect">Force Disconnect</button>
    </div>

    <div class="section">
        <h2>Event Log</h2>
        <div id="log"></div>
    </div>

    <script src="https://cdn.socket.io/4.7.5/socket.io.min.js"></script>
    <script>
        const logEl = document.getElementById('log');
        const log = (msg) => {
            const entry = document.createElement('div');
            entry.className = 'log-entry';
            entry.textContent = '[' + new Date().toLocaleTimeString() + '] ' + msg;
            logEl.prepend(entry);
        };

        const updateStatus = (state, socketId) => {
            const status = document.getElementById('connection-status');
            status.textContent = state.charAt(0).toUpperCase() + state.slice(1);
            status.className = 'status ' + state;
            document.getElementById('socket-id').textContent = socketId || '-';
        };

        const socket = io({
            transports: ['websocket', 'polling'],
            reconnection: true,
            reconnectionAttempts: 10,
            reconnectionDelay: 1000,
        });

        socket.on('connect', () => {
            log('Connected — ' + socket.id);
            updateStatus('connected', socket.id);
        });

        socket.on('disconnect', (reason) => {
            log('Disconnected — ' + reason);
            updateStatus('disconnected');
        });

        socket.on('connect_error', (err) => {
            log('Connection error — ' + err.message);
            updateStatus('reconnecting');
        });

        socket.on('connection:ready', (data) => {
            log('Event: connection:ready — ' + JSON.stringify(data));
        });

        socket.on('server:pong', (data) => {
            log('Event: server:pong — ' + JSON.stringify(data));
        });

        socket.on('test:broadcast', (data) => {
            log('Event: test:broadcast — ' + JSON.stringify(data));
        });

        document.getElementById('btn-ping').addEventListener('click', () => {
            const ts = new Date().toISOString();
            socket.emit('client:ping', { timestamp: ts }, (ack) => {
                log('Ack: client:ping — ' + JSON.stringify(ack));
            });
            log('Sent: client:ping — ' + ts);
        });

        document.getElementById('btn-broadcast').addEventListener('click', () => {
            socket.emit('test:broadcast', { message: 'Hello from ' + (socket.id || 'unknown') });
            log('Sent: test:broadcast');
        });

        document.getElementById('btn-disconnect').addEventListener('click', () => {
            socket.disconnect();
            log('Forced disconnect (auto-reconnect in 1s)');
        });
    </script>
</body>
</html>"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle application startup and shutdown events."""
    logger = logging.getLogger("app")

    logger.info(
        "CONFIG DIAGNOSTIC — env=%s host=%s port=%s name=%s user=%s password_set=%s url=%s",
        settings.APP_ENV,
        settings.DB_HOST,
        settings.DB_PORT,
        settings.DB_NAME,
        settings.DB_USER,
        bool(settings.DB_PASSWORD and settings.DB_PASSWORD != "change-me"),
        get_safe_database_url(),
        extra={"event": "config.diagnostic"},
    )

    logger.info(
        "Application startup — env=%s version=%s",
        settings.APP_ENV,
        settings.APP_VERSION,
        extra={
            "event": "application.startup",
            "environment": settings.APP_ENV,
            "version": settings.APP_VERSION,
        },
    )

    db_ready = await check_database_connection()
    if db_ready:
        logger.info(
            "Database connection established",
            extra={"event": "database.connection.success"},
        )
    else:
        logger.warning(
            "Database is not ready at startup; application will continue",
            extra={"event": "database.startup.not_ready"},
        )

    yield

    await engine.dispose()
    logger.info(
        "Application shutdown",
        extra={"event": "application.shutdown"},
    )


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    lifespan=lifespan,
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log incoming HTTP requests with structured metadata."""
    start_time = time.time()
    response = await call_next(request)
    duration_ms = (time.time() - start_time) * 1000

    logger = logging.getLogger("app")
    logger.info(
        "HTTP request",
        extra={
            "event": "http.request",
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": round(duration_ms, 2),
        },
    )
    return response


@app.get("/client", response_class=HTMLResponse)
async def client_page():
    """Serve the Socket.IO validation client."""
    return CLIENT_HTML


@app.api_route("/", methods=["GET", "HEAD"])
async def root():
    """Return application status."""
    return {
        "status": "running",
        "environment": settings.APP_ENV,
        "version": settings.APP_VERSION,
    }


@app.api_route("/health/live", methods=["GET", "HEAD"])
async def health_live():
    """Liveness probe. Confirms the application process is alive."""
    return {"status": "ok"}


@app.api_route("/health/ready", methods=["GET", "HEAD"])
async def health_ready():
    """Readiness probe. Confirms the application and PostgreSQL are operational."""
    db_ready = await check_database_connection()
    if db_ready:
        return {"status": "ready"}
    return JSONResponse(
        status_code=503,
        content={"status": "not ready"},
    )


@app.api_route("/info", methods=["GET", "HEAD"])
async def info():
    """Return application metadata from centralized configuration."""
    return {
        "application": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.APP_ENV,
    }


# Combine Socket.IO with FastAPI into a single ASGI application
socket_app = socketio.ASGIApp(sio, other_asgi_app=app)