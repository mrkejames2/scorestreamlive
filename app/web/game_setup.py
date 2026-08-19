"""Game setup / roster management web routes for Milestone 12-E."""

from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))


@router.get("/games/{game_id}/setup", response_class=HTMLResponse)
async def game_setup(request: Request, game_id: UUID) -> HTMLResponse:
    """Render roster management for an existing Game."""
    return templates.TemplateResponse(
        request=request,
        name="games/setup.html",
        context={
            "page_title": "Game Setup",
            "milestone": "M12-E",
            "game_id": str(game_id),
        },
    )
