"""Public post-purchase account activation and resend surfaces."""
from pathlib import Path

from fastapi import APIRouter, Depends, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.services.account_activation_service import (
    AccountActivationInvalid,
    consume_account_activation,
    request_activation_resend,
    resolve_account_activation,
)
from app.services.auth_service import create_user_session, set_session_cookie

router = APIRouter()
templates = Jinja2Templates(
    directory=str(Path(__file__).resolve().parents[2] / "templates")
)

GENERIC_RESEND_MESSAGE = (
    "If an account is waiting for activation, a new activation link has been sent."
)


def _invalid(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="auth/activate_account_invalid.html",
        context={},
        status_code=400,
    )


@router.get("/activate-account", response_class=HTMLResponse)
async def activation_page(
    request: Request,
    token: str = "",
    db: AsyncSession = Depends(get_session),
):
    try:
        _, user, club = await resolve_account_activation(db, token)
    except AccountActivationInvalid:
        return _invalid(request)

    return templates.TemplateResponse(
        request=request,
        name="auth/activate_account.html",
        context={
            "token": token,
            "user": user,
            "club": club,
            "error": None,
        },
    )


@router.post("/activate-account", response_class=HTMLResponse)
async def activation_submit(
    request: Request,
    token: str = Form(...),
    password: str = Form(...),
    confirm_password: str = Form(...),
    db: AsyncSession = Depends(get_session),
):
    require_same_origin_mutation(request)

    try:
        _, user, club = await resolve_account_activation(db, token)
    except AccountActivationInvalid:
        return _invalid(request)

    if password != confirm_password:
        return templates.TemplateResponse(
            request=request,
            name="auth/activate_account.html",
            context={
                "token": token,
                "user": user,
                "club": club,
                "error": "Passwords do not match.",
            },
            status_code=422,
        )

    try:
        user = await consume_account_activation(
            db, raw_token=token, password=password
        )
    except AccountActivationInvalid:
        return _invalid(request)
    except ValueError as exc:
        return templates.TemplateResponse(
            request=request,
            name="auth/activate_account.html",
            context={
                "token": token,
                "user": user,
                "club": club,
                "error": str(exc),
            },
            status_code=422,
        )

    _, raw_session = await create_user_session(db, user)
    response = RedirectResponse(url="/games", status_code=303)
    set_session_cookie(response, raw_session)
    return response


@router.get("/resend-activation", response_class=HTMLResponse)
async def resend_page(request: Request):
    return templates.TemplateResponse(
        request=request,
        name="auth/resend_activation.html",
        context={"message": None},
    )


@router.post("/resend-activation", response_class=HTMLResponse)
async def resend_submit(
    request: Request,
    email: str = Form(...),
    db: AsyncSession = Depends(get_session),
):
    require_same_origin_mutation(request)
    await request_activation_resend(db, email)
    return templates.TemplateResponse(
        request=request,
        name="auth/resend_activation.html",
        context={"message": GENERIC_RESEND_MESSAGE},
    )
