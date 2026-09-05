import uuid
from fastapi import APIRouter,Depends,HTTPException,status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import require_director
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.user import User
from app.services.email_service import EmailDeliveryError
from app.services.invitation_service import InvitationConflict,InvitationNotFound,create_invitation,payload,list_club_invitations,resend_invitation,revoke_invitation
router=APIRouter(prefix="/api/admin/invitations",tags=["invitations"])
class InvitationCreate(BaseModel): email:str;display_name:str|None=None;role:ClubRole
def director(u):
    require_director(u)
    if not u.club_id: raise HTTPException(404,"Club not found")
    return u.club_id
def out(i,preview=None):
    d=payload(i)
    if preview:d["delivery_preview_url"]=preview
    return d
@router.get("")
async def listing(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)): return [payload(x) for x in await list_club_invitations(db,director(current_user))]
@router.post("",status_code=status.HTTP_201_CREATED)
async def invite(data:InvitationCreate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    director(current_user)
    try:i,p=await create_invitation(db,inviter=current_user,email=data.email,display_name=data.display_name,role=data.role);return out(i,p)
    except InvitationConflict as e: raise HTTPException(409,str(e)) from e
    except EmailDeliveryError as e: raise HTTPException(503,"Invitation could not be sent. Please try again.") from e
    except ValueError as e: raise HTTPException(422,str(e)) from e
@router.post("/{invitation_id}/resend")
async def resend(invitation_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    director(current_user)
    try:i,p=await resend_invitation(db,inviter=current_user,invitation_id=invitation_id);return out(i,p)
    except InvitationNotFound as e: raise HTTPException(404,str(e)) from e
    except InvitationConflict as e: raise HTTPException(409,str(e)) from e
    except EmailDeliveryError as e: raise HTTPException(503,"Invitation could not be sent. Please try again.") from e
@router.delete("/{invitation_id}",status_code=status.HTTP_204_NO_CONTENT)
async def revoke(invitation_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    try: await revoke_invitation(db,club_id=director(current_user),invitation_id=invitation_id)
    except InvitationNotFound as e: raise HTTPException(404,str(e)) from e
    except InvitationConflict as e: raise HTTPException(409,str(e)) from e
