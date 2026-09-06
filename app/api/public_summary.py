"""Public Game summary API and presentation routes for M17-C."""

import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.encoders import jsonable_encoder
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import deny_not_found
from app.database import get_session
from app.services.public_game_summary_service import (
    PublicGameSummaryNotFound,
    get_public_game_summary,
)

router = APIRouter(tags=["public-summary"])
BASE_DIR = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


async def _require_public_summary(
    db: AsyncSession,
    game_id: uuid.UUID,
):
    try:
        return await get_public_game_summary(db, game_id)
    except PublicGameSummaryNotFound:
        deny_not_found("Game")


@router.get(
    "/api/public/games/{game_id}/summary",
    include_in_schema=False,
)
async def public_game_summary(
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    """Return a presentation-safe unauthenticated read-only Game summary."""
    summary = await _require_public_summary(db, game_id)
    return jsonable_encoder(summary)


@router.get(
    "/summary/games/{game_id}",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def public_summary_page(
    request: Request,
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    await _require_public_summary(db, game_id)
    return templates.TemplateResponse(
        request=request,
        name="summary/game.html",
        context={"game_id": str(game_id)},
    )


@router.get(
    "/broadcast/games/{game_id}",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def public_broadcast_page(
    request: Request,
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    await _require_public_summary(db, game_id)
    return templates.TemplateResponse(
        request=request,
        name="broadcast/game.html",
        context={"game_id": str(game_id)},
    )
