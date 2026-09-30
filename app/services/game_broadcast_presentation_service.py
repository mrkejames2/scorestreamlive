from datetime import datetime,timezone
from fastapi import HTTPException
from app.models.game import Game
from app.models.game_broadcast_presentation import GameBroadcastPresentation
from app.models.game_halftime_slideshow import GameHalftimeSlideshow,GameHalftimeSlideshowSlide
from app.models.broadcast_artwork import BroadcastArtwork
from sqlalchemy import select
VALID_SCENES={"intro","live","advertisement","halftime_slideshow","summary","thank_you"}
def _now():return datetime.now(timezone.utc)
def _versioned_asset_url(url,updated_at):
 if not url:return None
 if not updated_at:return url
 separator="&" if "?" in url else "?"
 return f"{url}{separator}v={updated_at.isoformat()}"
async def serialize_broadcast_state(db,game_id):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 row=await db.get(GameBroadcastPresentation,game_id);intro_available=bool(game.intro_enabled and game.intro_image_url);advertisement_available=bool(game.advertisement_enabled and game.advertisement_image_url);thank_available=bool(game.thank_you_enabled and game.thank_you_image_url);slideshow=await db.get(GameHalftimeSlideshow,game_id);slide_pairs=(await db.execute(select(GameHalftimeSlideshowSlide,BroadcastArtwork).join(BroadcastArtwork,BroadcastArtwork.id==GameHalftimeSlideshowSlide.artwork_id).where(GameHalftimeSlideshowSlide.game_id==game_id).order_by(GameHalftimeSlideshowSlide.position))).all();slideshow_available=bool(slideshow and slideshow.enabled and slide_pairs);scene=row.scene if row else ("intro" if intro_available else "live")
 if scene=="intro" and not intro_available:scene="live"
 if scene=="advertisement" and not advertisement_available:scene="live"
 if scene=="thank_you" and not thank_available:scene="live"
 if scene=="halftime_slideshow" and not slideshow_available:scene="live"
 return {"game_id":str(game.id),"scene":scene,"version":row.version if row else 0,"updated_at":row.updated_at if row else (game.intro_updated_at or game.advertisement_updated_at or game.thank_you_updated_at),"intro":{"enabled":bool(game.intro_enabled),"image_url":_versioned_asset_url(game.intro_image_url,game.intro_updated_at) if intro_available else None},"advertisement":{"enabled":bool(game.advertisement_enabled),"image_url":_versioned_asset_url(game.advertisement_image_url,game.advertisement_updated_at) if advertisement_available else None},"halftime_slideshow":{"enabled":bool(slideshow and slideshow.enabled),"interval_seconds":slideshow.interval_seconds if slideshow else 10,"slides":[{"id":str(s.id),"artwork_id":str(a.id),"name":a.name,"image_url":a.image_url,"position":s.position} for s,a in slide_pairs]},"thank_you":{"enabled":bool(game.thank_you_enabled),"image_url":_versioned_asset_url(game.thank_you_image_url,game.thank_you_updated_at) if thank_available else None}}
async def update_broadcast_scene(db,game_id,scene,expected_version):
 game=await db.get(Game,game_id)
 if not game:raise HTTPException(404,"Game not found")
 if game.archived_at is not None:raise HTTPException(409,"Archived Games are read-only")
 if scene not in VALID_SCENES:raise HTTPException(422,"Unsupported broadcast scene")
 if scene=="intro" and not(game.intro_enabled and game.intro_image_url):raise HTTPException(409,"Welcome Screen is not available")
 if scene=="advertisement" and not(game.advertisement_enabled and game.advertisement_image_url):raise HTTPException(409,"Advertisement is not available")
 if scene=="thank_you" and not(game.thank_you_enabled and game.thank_you_image_url):raise HTTPException(409,"Thank You Screen is not available")
 if scene=="halftime_slideshow":
  slideshow=await db.get(GameHalftimeSlideshow,game_id);has_slide=(await db.execute(select(GameHalftimeSlideshowSlide.id).where(GameHalftimeSlideshowSlide.game_id==game_id).limit(1))).scalar_one_or_none()
  if not slideshow or not slideshow.enabled or has_slide is None:raise HTTPException(409,"Halftime Slideshow is not available")
 row=await db.get(GameBroadcastPresentation,game_id);now=_now()
 if row is None:
  if expected_version not in (None,0):raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row=GameBroadcastPresentation(game_id=game_id,scene=scene,version=1,created_at=now,updated_at=now);db.add(row)
 else:
  if expected_version is not None and row.version!=expected_version:raise HTTPException(409,"Broadcast presentation changed; refetch current state")
  row.scene=scene;row.version+=1;row.updated_at=now
 await db.commit();await db.refresh(row);return await serialize_broadcast_state(db,game_id)
