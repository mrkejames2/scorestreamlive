from datetime import datetime,timezone
from fastapi import HTTPException
from app.models.game import Game
from app.models.game_broadcast_presentation import GameBroadcastPresentation
def _now():return datetime.now(timezone.utc)
async def serialize_broadcast_state(db,game_id):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 row=await db.get(GameBroadcastPresentation,game_id);available=bool(game.intro_enabled and game.intro_image_url);scene=row.scene if row else ("intro" if available else "live")
 if scene=="intro" and not available:scene="live"
 return {"game_id":str(game.id),"scene":scene,"version":row.version if row else 0,"updated_at":row.updated_at if row else game.intro_updated_at,"intro":{"enabled":bool(game.intro_enabled),"image_url":game.intro_image_url if available else None}}
async def update_broadcast_scene(db,game_id,scene,expected_version):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 if game.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 if scene not in {"intro","live"}:raise HTTPException(422,"Unsupported broadcast scene")
 if scene=="intro" and not(game.intro_enabled and game.intro_image_url):raise HTTPException(409,"Welcome Screen is not available")
 row=await db.get(GameBroadcastPresentation,game_id);now=_now()
 if row is None:
  if expected_version not in (None,0):raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row=GameBroadcastPresentation(game_id=game_id,scene=scene,version=1,created_at=now,updated_at=now);db.add(row)
 else:
  if expected_version is not None and row.version!=expected_version:raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row.scene=scene;row.version+=1;row.updated_at=now
 await db.commit();await db.refresh(row);return await serialize_broadcast_state(db,game_id)
