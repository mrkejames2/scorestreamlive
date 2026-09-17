"""Director-facing sponsor management page for M19-B."""
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.services.club_service import get_club

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[2] / "templates"))

@router.get("/account/sponsors", response_class=HTMLResponse)
async def sponsors_page(request: Request, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    if current_user.club_id is None:
        raise HTTPException(status_code=409, detail="User is not assigned to a Club")
    if current_user.club_role != "DIRECTOR":
        raise HTTPException(status_code=403, detail="Director access required.")
    club = await get_club(db, current_user.club_id)
    return templates.TemplateResponse(request=request, name="account/sponsors.html", context={"current_user": current_user, "club": club})
