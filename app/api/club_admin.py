"""M15-D Director management API."""
import uuid
from fastapi import APIRouter,Depends,HTTPException,status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import require_director
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.user import User
from app.services.access_admin_service import list_club_members,create_club_member,assign_team_manager,assign_game_operator,remove_team_manager,remove_game_operator,assignments
router=APIRouter(prefix="/api/admin",tags=["club-admin"])
class MemberCreate(BaseModel):
    email:str;display_name:str|None=None;role:ClubRole;temporary_password:str
class AssignmentCreate(BaseModel): user_id:uuid.UUID
def director(u):
    require_director(u);return u.club_id
def member(u):return {"id":str(u.id),"email":u.email,"display_name":u.display_name,"club_role":u.club_role,"is_active":u.is_active}
@router.get("/members")
async def members(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    return [member(u) for u in await list_club_members(db,director(current_user))]
@router.post("/members",status_code=201)
async def create_member(data:MemberCreate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    try:u=await create_club_member(db,director(current_user),data.email,data.display_name,data.role,data.temporary_password)
    except ValueError as e:raise HTTPException(status_code=422,detail=str(e))
    return member(u)
@router.get("/assignments")
async def get_assignments(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    return await assignments(db,director(current_user))
@router.post("/teams/{team_id}/managers",status_code=201)
async def add_manager(team_id:uuid.UUID,data:AssignmentCreate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    try:a=await assign_team_manager(db,director(current_user),team_id,data.user_id)
    except ValueError as e:raise HTTPException(status_code=422,detail=str(e))
    return {"id":str(a.id),"team_id":str(a.team_id),"user_id":str(a.user_id)}
@router.delete("/teams/{team_id}/managers/{user_id}",status_code=204)
async def del_manager(team_id:uuid.UUID,user_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    try:await remove_team_manager(db,director(current_user),team_id,user_id)
    except ValueError as e:raise HTTPException(status_code=404,detail=str(e))
@router.post("/games/{game_id}/operators",status_code=201)
async def add_operator(game_id:uuid.UUID,data:AssignmentCreate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    try:a=await assign_game_operator(db,director(current_user),game_id,data.user_id)
    except ValueError as e:raise HTTPException(status_code=422,detail=str(e))
    return {"id":str(a.id),"game_id":str(a.game_id),"user_id":str(a.user_id)}
@router.delete("/games/{game_id}/operators/{user_id}",status_code=204)
async def del_operator(game_id:uuid.UUID,user_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    try:await remove_game_operator(db,director(current_user),game_id,user_id)
    except ValueError as e:raise HTTPException(status_code=404,detail=str(e))
