"""Game Detail / Launch Hub web route for Milestone 12-F."""

from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))


@router.get("/games/{game_id}", response_class=HTMLResponse)
async def game_detail(request: Request, game_id: UUID) -> HTMLResponse:
    """Render the authoritative Game Detail / Launch Hub."""
    return templates.TemplateResponse(
        request=request,
        name="games/detail.html",
        context={
            "page_title": "Game Detail",
            "milestone": "M12-F",
            "game_id": str(game_id),
        },
    )
