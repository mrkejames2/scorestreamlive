import uuid
from datetime import datetime,timezone
from fastapi import APIRouter,Depends,File,Form,HTTPException,Request,Response,UploadFile
from fastapi.responses import FileResponse
from sqlalchemy import or_,select
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.broadcast_artwork import BroadcastArtwork
from app.models.game import Game
from app.models.user import User
from app.services.broadcast_artwork_storage import *
router=APIRouter(tags=["broadcast-artwork"])
def reader(u):
    if u.club_id is None:raise HTTPException(409,"User is not assigned to a Club")
    if u.club_role not in {"DIRECTOR","MANAGER"}:raise HTTPException(403,"Director or Manager access required")
    return u.club_id
def director(u):
    c=reader(u)
    if u.club_role!="DIRECTOR":raise HTTPException(403,"Director access required")
    return c
def out(a):return {"id":str(a.id),"name":a.name,"image_url":a.image_url,"created_at":a.created_at,"updated_at":a.updated_at}
async def owned(db,c,i):
    a=await db.get(BroadcastArtwork,i)
    if not a or a.club_id!=c:raise HTTPException(404,"Broadcast artwork not found")
    return a
@router.get("/api/account/broadcast-artwork")
async def listing(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    c=reader(current_user);rows=(await db.execute(select(BroadcastArtwork).where(BroadcastArtwork.club_id==c).order_by(BroadcastArtwork.name))).scalars().all()
    return {"can_manage":current_user.club_role=="DIRECTOR","items":[out(x) for x in rows]}
@router.post("/api/account/broadcast-artwork",status_code=201)
async def create(request:Request,name:str=Form(...),artwork:UploadFile=File(...),current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request);c=director(current_user);name=name.strip()
    if not name or len(name)>255:raise HTTPException(422,"Artwork name must be 1-255 characters")
    n=None
    try:n=await save_broadcast_artwork(club_id=c,upload=artwork)
    except BroadcastArtworkTooLargeError as e:raise HTTPException(413,str(e))
    except BroadcastArtworkUnsupportedTypeError as e:raise HTTPException(415,str(e))
    finally:await artwork.close()
    now=datetime.now(timezone.utc);a=BroadcastArtwork(club_id=c,name=name,image_url=f"/api/broadcast-artwork-assets/{n}",created_by_user_id=current_user.id,created_at=now,updated_at=now);db.add(a)
    try:await db.commit();await db.refresh(a)
    except Exception:delete_filename(n);raise
    return out(a)
@router.patch("/api/account/broadcast-artwork/{artwork_id}")
async def rename(artwork_id:uuid.UUID,data:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request);a=await owned(db,director(current_user),artwork_id);n=data.get("name")
    if not isinstance(n,str) or not n.strip() or len(n.strip())>255:raise HTTPException(422,"Artwork name must be 1-255 characters")
    a.name=n.strip();a.updated_at=datetime.now(timezone.utc);await db.commit();await db.refresh(a);return out(a)
@router.delete("/api/account/broadcast-artwork/{artwork_id}",status_code=204)
async def remove(artwork_id:uuid.UUID,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request);c=director(current_user);a=await owned(db,c,artwork_id)
    used=(await db.execute(select(Game.id).where(Game.club_id==c,or_(Game.intro_artwork_id==a.id,Game.thank_you_artwork_id==a.id)).limit(1))).scalar_one_or_none()
    if used is not None:raise HTTPException(409,"Artwork is currently assigned to one or more games")
    n=filename_from_url(a.image_url);await db.delete(a);await db.commit();delete_filename(n);return Response(status_code=204)
@router.get("/api/broadcast-artwork-assets/{filename}")
async def asset(filename:str):
    try:p=path_for_filename(filename)
    except FileNotFoundError:raise HTTPException(404,"Broadcast artwork asset not found")
    return FileResponse(p,headers={"Cache-Control":"public, max-age=31536000, immutable"})
