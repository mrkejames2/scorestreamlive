"""ScoreStreamLive application entrypoint."""

import logging
import time
import uuid
from contextlib import asynccontextmanager

import socketio
from fastapi import FastAPI, Request
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

from app.api.auth import router as auth_router
from app.api.billing_webhooks import router as billing_webhooks_router
from app.api.clubs import router as clubs_router
from app.api.club_admin import router as club_admin_router
from app.api.control import router as control_router
from app.api.game_clock import router as game_clock_router
from app.api.game_lifecycle import router as game_lifecycle_router
from app.api.games import router as games_router
from app.api.invitations import router as invitations_router
from app.api.players import router as players_router
from app.api.public_summary import router as public_summary_router
from app.api.scoring_events import router as scoring_events_router
from app.api.support import router as support_router
from app.api.public_signup import router as public_signup_router
from app.api.public_checkout import router as public_checkout_router
from app.api.team_logos import router as team_logos_router
from app.api.teams import router as teams_router
from app.auth.security import enforce_production_security_settings
from app.config import settings
from app.database import check_database_connection, engine, get_safe_database_url
from app.logging_config import configure_logging, reset_request_id, set_request_id
from app.services.team_logo_storage import ensure_storage_dir
from app.sockets import sio
from app.web.auth import router as auth_web_router
from app.web.account import router as account_web_router
from app.web.activation import router as activation_web_router
from app.web.password_recovery import router as password_recovery_web_router
from app.web.games import router as games_web_router
from app.web.game_setup import router as game_setup_web_router
from app.web.game_detail import router as game_detail_web_router
from app.web.teams import router as teams_web_router
from app.web.signup import router as signup_web_router
from app.web.checkout import router as checkout_web_router

configure_logging(settings.LOG_LEVEL)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger = logging.getLogger("app")
    enforce_production_security_settings()
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
        "Application startup — env=%s version=%s release=%s",
        settings.APP_ENV,
        settings.APP_VERSION,
        settings.APP_RELEASE,
        extra={
            "event": "application.startup",
            "environment": settings.APP_ENV,
            "version": settings.APP_VERSION,
            "release": settings.APP_RELEASE,
        },
    )

    logo_dir = ensure_storage_dir()
    logger.info(
        "Team logo storage ready — path=%s max_bytes=%s",
        logo_dir,
        settings.TEAM_LOGO_MAX_BYTES,
        extra={"event": "team_logo.storage.ready"},
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

app.mount("/static", StaticFiles(directory="static"), name="static")

app.include_router(auth_router)
app.include_router(billing_webhooks_router)
app.include_router(clubs_router)
app.include_router(club_admin_router)
app.include_router(game_lifecycle_router)
app.include_router(game_clock_router)
app.include_router(scoring_events_router)
app.include_router(games_router)
app.include_router(invitations_router)
app.include_router(players_router)
app.include_router(public_summary_router)
app.include_router(teams_router)
app.include_router(team_logos_router)
app.include_router(control_router)
app.include_router(support_router)
app.include_router(public_signup_router)
app.include_router(public_checkout_router)
app.include_router(auth_web_router)
app.include_router(account_web_router)
app.include_router(activation_web_router)
app.include_router(password_recovery_web_router)
app.include_router(games_web_router)
app.include_router(game_setup_web_router)
app.include_router(game_detail_web_router)
app.include_router(teams_web_router)
app.include_router(signup_web_router)
app.include_router(checkout_web_router)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    request_id = str(uuid.uuid4())
    context_token = set_request_id(request_id)
    start_time = time.perf_counter()
    logger = logging.getLogger("app")

    try:
        response = await call_next(request)
        duration_ms = (time.perf_counter() - start_time) * 1000

        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "same-origin"
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["X-Request-ID"] = request_id
        response.headers["X-ScoreStreamLive-Release"] = settings.APP_RELEASE

        logger.info(
            "HTTP request",
            extra={
                "event": "http.request",
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round(duration_ms, 2),
                "release": settings.APP_RELEASE,
            },
        )
        return response
    except Exception:
        duration_ms = (time.perf_counter() - start_time) * 1000
        logger.exception(
            "Unhandled HTTP request exception",
            extra={
                "event": "http.request.exception",
                "method": request.method,
                "path": request.url.path,
                "duration_ms": round(duration_ms, 2),
                "release": settings.APP_RELEASE,
            },
        )
        raise
    finally:
        reset_request_id(context_token)


@app.get("/client")
async def client_page():
    return FileResponse("static/technical-client.html")


@app.api_route("/", methods=["GET", "HEAD"])
async def root():
    return FileResponse("static/index.html")


@app.api_route("/health/live", methods=["GET", "HEAD"])
async def health_live():
    return {"status": "ok"}


@app.api_route("/health/ready", methods=["GET", "HEAD"])
async def health_ready():
    db_ready = await check_database_connection()
    if db_ready:
        return {"status": "ready"}

    return JSONResponse(
        status_code=503,
        content={"status": "not ready"},
    )


@app.api_route("/info", methods=["GET", "HEAD"])
async def info():
    return {
        "application": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "release": settings.APP_RELEASE,
        "environment": settings.APP_ENV,
    }


if settings.APP_ENV == "production":
    sio.handlers.get("/", {}).pop("test:broadcast", None)

socket_app = socketio.ASGIApp(sio, other_asgi_app=app)
