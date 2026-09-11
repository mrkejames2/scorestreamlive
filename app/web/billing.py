from pathlib import Path
from fastapi import APIRouter,Depends,HTTPException,Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.plan import Plan
from app.models.subscription import Subscription
from app.services.club_service import get_club
router=APIRouter();templates=Jinja2Templates(directory=str(Path(__file__).resolve().parents[2]/"templates"))
@router.get("/account/billing",response_class=HTMLResponse)
async def billing(request:Request,current_user=Depends(require_current_user),db=Depends(get_session)):
 if current_user.club_role!="DIRECTOR" or current_user.club_id is None: raise HTTPException(status_code=403,detail="Director access required.")
 club=await get_club(db,current_user.club_id);row=(await db.execute(select(Subscription,Plan).join(Plan,Plan.id==Subscription.plan_id).where(Subscription.club_id==current_user.club_id))).first();subscription,plan=row if row else (None,None)
 return templates.TemplateResponse(request=request,name="account/billing.html",context={"current_user":current_user,"club":club,"subscription":subscription,"plan":plan})
