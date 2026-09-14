"""Director-facing premium Club branding management page for M18-G2."""
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.services.club_branding_service import get_club_branding
from app.services.club_service import get_club
from app.services.entitlement_service import CUSTOM_OVERLAY_BRANDING, effective_club_has_entitlement

router = APIRouter()
templates = Jinja2Templates(directory=str(Path(__file__).resolve().parents[2] / "templates"))

@router.get("/account/branding", response_class=HTMLResponse)
async def branding_page(request: Request, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    if current_user.club_role != "DIRECTOR" or current_user.club_id is None:
        raise HTTPException(status_code=403, detail="Director access required.")
    club = await get_club(db, current_user.club_id)
    branding_enabled = await effective_club_has_entitlement(db, current_user.club_id, CUSTOM_OVERLAY_BRANDING)
    branding = await get_club_branding(db, current_user.club_id) if branding_enabled else None
    return templates.TemplateResponse(
        request=request,
        name="account/branding.html",
        context={"current_user": current_user, "club": club, "branding_enabled": branding_enabled, "branding": branding},
    )
