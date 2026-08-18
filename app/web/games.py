"""Read-only Game Management web routes for Milestone 12-A."""

from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))


@router.get("/games", response_class=HTMLResponse)
async def game_management_home(request: Request) -> HTMLResponse:
    """Render the read-only Game Management home."""
    return templates.TemplateResponse(
        request=request,
        name="games/index.html",
        context={
            "page_title": "Games",
            "milestone": "M12-A",
        },
    )
