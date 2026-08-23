from pathlib import Path
from fastapi import APIRouter,Depends,Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.services.club_service import get_club
router=APIRouter();templates=Jinja2Templates(directory=str(Path(__file__).resolve().parents[2]/"templates"))
@router.get("/account",response_class=HTMLResponse)
async def account_home(request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club=await get_club(db,current_user.club_id) if current_user.club_id else None
    return templates.TemplateResponse(request=request,name="account/index.html",context={"current_user":current_user,"club":club,"is_director":current_user.club_role=="DIRECTOR"})
