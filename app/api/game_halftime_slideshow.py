import uuid
from datetime import datetime,timezone
from fastapi import APIRouter,Depends,HTTPException,Request,Response
from fastapi.encoders import jsonable_encoder
from sqlalchemy import func,select
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.authorization import can_operate_game,deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.database import get_session
from app.models.broadcast_artwork import BroadcastArtwork
from app.models.game import Game
from app.models.game_halftime_slideshow import GameHalftimeSlideshow,GameHalftimeSlideshowSlide
from app.models.user import User
from app.services.game_broadcast_presentation_service import serialize_broadcast_state
from app.sockets import sio,game_room
router=APIRouter(tags=["halftime-slideshow"]);INTERVALS={5,10,15,20,30}
async def manageable(db,u,gid):
 if u.club_role not in {"DIRECTOR","MANAGER"}:raise HTTPException(403,"Director or Manager access required")
 g=await db.get(Game,gid)
 if not g or not await can_operate_game(db,u,g):deny_not_found("Game")
 if g.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 return g
async def ensure(db,gid):
 r=await db.get(GameHalftimeSlideshow,gid)
 if r is None:
  n=datetime.now(timezone.utc);r=GameHalftimeSlideshow(game_id=gid,enabled=False,interval_seconds=10,created_at=n,updated_at=n);db.add(r);await db.flush()
 return r
async def pairs(db,gid):
 return (await db.execute(select(GameHalftimeSlideshowSlide,BroadcastArtwork).join(BroadcastArtwork,BroadcastArtwork.id==GameHalftimeSlideshowSlide.artwork_id).where(GameHalftimeSlideshowSlide.game_id==gid).order_by(GameHalftimeSlideshowSlide.position))).all()
async def state(db,gid):
 r=await db.get(GameHalftimeSlideshow,gid);ps=await pairs(db,gid)
 return {"game_id":str(gid),"enabled":bool(r.enabled) if r else False,"interval_seconds":r.interval_seconds if r else 10,"slides":[{"id":str(s.id),"artwork_id":str(a.id),"name":a.name,"image_url":a.image_url,"position":s.position} for s,a in ps]}
async def emit(db,gid):await sio.emit("broadcast:presentation_updated",jsonable_encoder(await serialize_broadcast_state(db,gid)),room=game_room(gid,"overlay"))
@router.get("/api/games/{game_id}/halftime-slideshow")
async def get(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 await manageable(db,current_user,game_id);return await state(db,game_id)
@router.put("/api/games/{game_id}/halftime-slideshow")
async def update(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);await manageable(db,current_user,game_id);enabled=payload.get("enabled");interval=payload.get("interval_seconds")
 if not isinstance(enabled,bool):raise HTTPException(422,"enabled must be boolean")
 if not isinstance(interval,int) or interval not in INTERVALS:raise HTTPException(422,"interval_seconds must be one of 5, 10, 15, 20, 30")
 r=await ensure(db,game_id);count=(await db.execute(select(func.count()).select_from(GameHalftimeSlideshowSlide).where(GameHalftimeSlideshowSlide.game_id==game_id))).scalar_one()
 if enabled and count<1:raise HTTPException(409,"Add at least one slideshow image before enabling")
 r.enabled=enabled;r.interval_seconds=interval;r.updated_at=datetime.now(timezone.utc);await db.commit();await emit(db,game_id);return await state(db,game_id)
@router.post("/api/games/{game_id}/halftime-slideshow/slides",status_code=201)
async def add(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);g=await manageable(db,current_user,game_id)
 try:aid=uuid.UUID(str(payload.get("artwork_id")))
 except Exception:raise HTTPException(422,"Valid artwork_id required")
 a=await db.get(BroadcastArtwork,aid)
 if not a or a.club_id!=g.club_id:raise HTTPException(404,"Broadcast artwork not found")
 if (await db.execute(select(GameHalftimeSlideshowSlide.id).where(GameHalftimeSlideshowSlide.game_id==game_id,GameHalftimeSlideshowSlide.artwork_id==aid))).scalar_one_or_none() is not None:raise HTTPException(409,"Artwork is already in this slideshow")
 await ensure(db,game_id);mx=(await db.execute(select(func.max(GameHalftimeSlideshowSlide.position)).where(GameHalftimeSlideshowSlide.game_id==game_id))).scalar_one();n=datetime.now(timezone.utc);db.add(GameHalftimeSlideshowSlide(game_id=game_id,artwork_id=aid,position=(mx if mx is not None else -1)+1,created_at=n,updated_at=n));await db.commit();await emit(db,game_id);return await state(db,game_id)
@router.delete("/api/games/{game_id}/halftime-slideshow/slides/{slide_id}",status_code=204)
async def remove(game_id:uuid.UUID,slide_id:uuid.UUID,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);await manageable(db,current_user,game_id);s=await db.get(GameHalftimeSlideshowSlide,slide_id)
 if not s or s.game_id!=game_id:raise HTTPException(404,"Slideshow slide not found")
 await db.delete(s);await db.flush();left=(await db.execute(select(GameHalftimeSlideshowSlide).where(GameHalftimeSlideshowSlide.game_id==game_id).order_by(GameHalftimeSlideshowSlide.position))).scalars().all();n=datetime.now(timezone.utc)
 for i,x in enumerate(left):x.position=100000+i
 await db.flush()
 for i,x in enumerate(left):x.position=i;x.updated_at=n
 await db.flush()
 r=await db.get(GameHalftimeSlideshow,game_id)
 if r and not left:r.enabled=False;r.updated_at=n
 await db.commit();await emit(db,game_id);return Response(status_code=204)
@router.put("/api/games/{game_id}/halftime-slideshow/slides/order")
async def reorder(game_id:uuid.UUID,payload:dict,request:Request,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
 require_same_origin_mutation(request);await manageable(db,current_user,game_id);raw=payload.get("slide_ids")
 if not isinstance(raw,list):raise HTTPException(422,"slide_ids must be an array")
 try:wanted=[uuid.UUID(str(x)) for x in raw]
 except Exception:raise HTTPException(422,"slide_ids contains an invalid id")
 slides=(await db.execute(select(GameHalftimeSlideshowSlide).where(GameHalftimeSlideshowSlide.game_id==game_id))).scalars().all();cur={x.id:x for x in slides}
 if len(wanted)!=len(cur) or set(wanted)!=set(cur):raise HTTPException(409,"slide_ids must contain every current slide exactly once")
 for i,x in enumerate(slides):x.position=100000+i
 await db.flush();n=datetime.now(timezone.utc)
 for i,sid in enumerate(wanted):cur[sid].position=i;cur[sid].updated_at=n
 await db.commit();await emit(db,game_id);return await state(db,game_id)
