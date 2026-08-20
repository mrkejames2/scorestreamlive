"""Team Management web routes for Milestone 13."""

from pathlib import Path
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

router = APIRouter()
PROJECT_ROOT = Path(__file__).resolve().parents[2]
templates = Jinja2Templates(directory=str(PROJECT_ROOT / "templates"))

@router.get("/teams", response_class=HTMLResponse)
async def team_management_home(request: Request) -> HTMLResponse:
    return templates.TemplateResponse(
        request=request, name="teams/index.html",
        context={"page_title": "Teams", "milestone": "M13-C"},
    )

@router.get("/teams/{team_id}", response_class=HTMLResponse)
async def team_detail(request: Request, team_id: UUID) -> HTMLResponse:
    """Render the Team Detail / read-only roster surface."""
    return templates.TemplateResponse(
        request=request, name="teams/detail.html",
        context={"page_title": "Team Detail", "milestone": "M13-C", "team_id": str(team_id)},
    )
