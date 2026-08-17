"""M10-A operator-facing Control Center page route.

This route serves the read-only Control Center shell.
It does not mutate game state and does not own authoritative game data.
"""

import uuid
from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates


router = APIRouter(tags=["control"])

BASE_DIR = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(BASE_DIR / "templates"))


@router.get(
    "/control/games/{game_id}",
    response_class=HTMLResponse,
    include_in_schema=False,
)
async def game_control_page(
    request: Request,
    game_id: uuid.UUID,
):
    return templates.TemplateResponse(
        request=request,
        name="control/game.html",
        context={
            "game_id": str(game_id),
        },
    )
