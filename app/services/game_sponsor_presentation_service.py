"""M19-E authoritative sponsor presentation controls and recovery."""
import uuid
from datetime import datetime,timezone
from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.game import Game
from app.models.game_sponsor_presentation import GameSponsorPresentation
from app.schemas.game_sponsor_presentation import ALLOWED_INTERVALS
from app.services.effective_game_sponsor_service import get_effective_game_sponsors
def _now(): return datetime.now(timezone.utc)
async def _game(db,game_id):
    g=await db.get(Game,game_id)
    if g is None: raise HTTPException(status_code=404,detail="Game not found")
    return g
async def get_or_create_presentation(db,game_id):
    g=await _game(db,game_id); row=await db.get(GameSponsorPresentation,game_id)
    if row is None:
        now=_now(); row=GameSponsorPresentation(game_id=game_id,current_sponsor_id=None,visible=True,rotation_enabled=True,rotation_interval_seconds=10,version=1,created_at=now,updated_at=now)
        db.add(row); await db.commit(); await db.refresh(row)
    return g,row
async def serialize_presentation(db,game_id):
    g,row=await get_or_create_presentation(db,game_id); sponsors=await get_effective_game_sponsors(db,g.id,g.club_id); ids=[str(s["id"]) for s in sponsors]
    current=str(row.current_sponsor_id) if row.current_sponsor_id else None
    if current not in ids: current=ids[0] if ids else None
    return {"game_id":str(g.id),"current_sponsor_id":current,"visible":bool(row.visible),"rotation_enabled":bool(row.rotation_enabled),"rotation_interval_seconds":int(row.rotation_interval_seconds),"version":int(row.version),"updated_at":row.updated_at,"sponsors":sponsors}
async def update_presentation(db,game_id,data):
    g,row=await get_or_create_presentation(db,game_id)
    if g.archived_at is not None: raise HTTPException(status_code=409,detail="Archived Games are read-only")
    if row.version!=data.expected_version: raise HTTPException(status_code=409,detail="Sponsor presentation changed; refetch current state")
    sponsors=await get_effective_game_sponsors(db,g.id,g.club_id); ids=[s["id"] for s in sponsors]; current=str(row.current_sponsor_id) if row.current_sponsor_id else None; idx=next((i for i,s in enumerate(ids) if str(s)==current),0)
    if data.action in ("next","previous"):
        row.current_sponsor_id=ids[(idx+(1 if data.action=="next" else -1))%len(ids)] if ids else None
    elif data.action=="set_visible":
        if data.visible is None: raise HTTPException(status_code=422,detail="visible is required")
        row.visible=data.visible
    elif data.action=="set_rotation":
        if data.rotation_enabled is None: raise HTTPException(status_code=422,detail="rotation_enabled is required")
        row.rotation_enabled=data.rotation_enabled
    elif data.action=="set_interval":
        if data.rotation_interval_seconds not in ALLOWED_INTERVALS: raise HTTPException(status_code=422,detail="Unsupported rotation interval")
        row.rotation_interval_seconds=data.rotation_interval_seconds
    if row.current_sponsor_id is None and ids: row.current_sponsor_id=ids[0]
    row.version+=1; row.updated_at=_now(); await db.commit(); await db.refresh(row); return await serialize_presentation(db,game_id)
