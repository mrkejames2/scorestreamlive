"""Browser login/logout routes for M15-A."""

from pathlib import Path
from urllib.parse import urlparse

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_session
from app.services.auth_service import (
    authenticate_user,
    clear_session_cookie,
    create_user_session,
    revoke_session,
    set_session_cookie,
)

router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))


def _safe_next(next_value: str | None) -> str:
    """Allow only local absolute-path redirects."""
    if not next_value:
        return "/games"
    parsed = urlparse(next_value)
    if parsed.scheme or parsed.netloc:
        return "/games"
    if next_value.startswith("/") and not next_value.startswith("//"):
        return next_value
    return "/games"


@router.get("/login", response_class=HTMLResponse)
async def login_page(request: Request, next: str | None = None) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request,
        name="auth/login.html",
        context={
            "page_title": "Sign in",
            "error": None,
            "next": _safe_next(next),
        },
    )


@router.post("/login", response_class=HTMLResponse)
async def login_submit(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
    next: str = Form("/games"),
    db: AsyncSession = Depends(get_session),
):
    user = await authenticate_user(db, email, password)
    if not user:
        return templates.TemplateResponse(
            request=request,
            name="auth/login.html",
            context={
                "page_title": "Sign in",
                "error": "Invalid email or password.",
                "next": _safe_next(next),
                "email": email,
            },
            status_code=401,
        )

    _, raw_token = await create_user_session(db, user)
    response = RedirectResponse(url=_safe_next(next), status_code=303)
    set_session_cookie(response, raw_token)
    return response


@router.post("/logout")
async def logout_submit(
    request: Request,
    db: AsyncSession = Depends(get_session),
):
    token = request.cookies.get(settings.AUTH_SESSION_COOKIE_NAME)
    await revoke_session(db, token)
    response = RedirectResponse(url="/login", status_code=303)
    clear_session_cookie(response)
    return response
