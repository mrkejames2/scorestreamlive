"""Read-only Team Management web routes for Milestone 13-A."""

from pathlib import Path

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates


router = APIRouter()

PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))


@router.get("/teams", response_class=HTMLResponse)
async def team_management_home(request: Request) -> HTMLResponse:
    """Render the read-only Team Management home."""
    return templates.TemplateResponse(
        request=request,
        name="teams/index.html",
        context={
            "page_title": "Teams",
            "milestone": "M13-A",
        },
    )
