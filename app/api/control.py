"""Operator-facing Control Center and public broadcast overlay routes."""

import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, Request
from fastapi.encoders import jsonable_encoder
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_operate_game, deny_not_found
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.services.game_clock_service import get_clock, serialize_clock_state
from app.services.game_lifecycle_service import get_lifecycle, serialize_lifecycle_state
from app.services.game_service import get_game
from app.services.player_service import get_team_players

router = APIRouter(tags=["control"])
BASE_DIR = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


def _public_team(team):
    if team is None:
        return None
    return {
        "id": str(team.id),
        "name": team.name,
        "short_name": team.short_name,
        "logo_url": team.logo_url,
        "primary_color": team.primary_color,
        "secondary_color": team.secondary_color,
    }


def _public_player(player):
    return {
        "id": str(player.id),
        "team_id": str(player.team_id),
        "first_name": player.first_name,
        "last_name": player.last_name,
        "jersey_number": player.jersey_number,
    }


@router.get(
    "/control/games/{game_id}",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def game_control_page(
    request: Request,
    game_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    game = await get_game(db, game_id)
    if not game or not await can_operate_game(db, current_user, game):
        deny_not_found("Game")

    return templates.TemplateResponse(
        request=request,
        name="control/game.html",
        context={"game_id": str(game_id), "current_user": current_user},
    )


@router.get(
    "/overlay/games/{game_id}",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def game_overlay_page(
    request: Request,
    game_id: uuid.UUID,
):
    return templates.TemplateResponse(
        request=request,
        name="overlay/game.html",
        context={"game_id": str(game_id)},
    )


@router.get(
    "/api/public/games/{game_id}/overlay-state",
    include_in_schema=False,
)
async def public_overlay_state(
    game_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    """Return the minimum unauthenticated read-only snapshot for an overlay."""
    game = await get_game(db, game_id)
    if not game:
        deny_not_found("Game")

    home_roster = (
        await get_team_players(db, game.home_team_id)
        if game.home_team_id
        else []
    )
    away_roster = (
        await get_team_players(db, game.away_team_id)
        if game.away_team_id
        else []
    )
    lifecycle = await get_lifecycle(db, game_id)
    clock = await get_clock(db, game_id)

    snapshot = {
        "game": {
            "id": str(game.id),
            "name": game.name,
            "status": game.status,
            "scheduled_at": game.scheduled_at,
            "home_team_id": str(game.home_team_id) if game.home_team_id else None,
            "away_team_id": str(game.away_team_id) if game.away_team_id else None,
            "home_score": game.home_score,
            "away_score": game.away_score,
            "broadcast_message": game.broadcast_message,
        },
        "home_team": _public_team(game.home_team),
        "away_team": _public_team(game.away_team),
        "lifecycle": serialize_lifecycle_state(lifecycle) if lifecycle else None,
        "clock": serialize_clock_state(clock) if clock else None,
        "home_roster": [_public_player(p) for p in home_roster],
        "away_roster": [_public_player(p) for p in away_roster],
    }
    return jsonable_encoder(snapshot)
