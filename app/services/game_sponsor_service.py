from datetime import datetime, timezone
from fastapi import HTTPException
from sqlalchemy import delete, select
from app.models.game import Game
from app.models.game_sponsor import GameSponsor
from app.models.sponsor import Sponsor
async def _club_game(db,club_id,game_id):
    r=await db.execute(select(Game).where(Game.id==game_id,Game.club_id==club_id)); g=r.scalar_one_or_none()
    if g is None: raise HTTPException(status_code=404,detail="Game not found")
    return g
async def list_game_sponsors(db,club_id,game_id):
    await _club_game(db,club_id,game_id)
    r=await db.execute(select(GameSponsor,Sponsor).join(Sponsor,Sponsor.id==GameSponsor.sponsor_id).where(GameSponsor.game_id==game_id,Sponsor.club_id==club_id).order_by(GameSponsor.display_order,Sponsor.name,Sponsor.id))
    return list(r.all())
async def replace_game_sponsors(db,club_id,game_id,sponsor_ids):
    g=await _club_game(db,club_id,game_id)
    if g.archived_at is not None: raise HTTPException(status_code=409,detail="Archived Games are read-only")
    ids=list(dict.fromkeys(sponsor_ids)); sponsors=[]
    if ids:
        r=await db.execute(select(Sponsor).where(Sponsor.club_id==club_id,Sponsor.id.in_(ids))); found={s.id:s for s in r.scalars().all()}
        if len(found)!=len(ids): raise HTTPException(status_code=422,detail="One or more Sponsors are not available to this Club")
        sponsors=[found[x] for x in ids]
    await db.execute(delete(GameSponsor).where(GameSponsor.game_id==game_id)); now=datetime.now(timezone.utc)
    for i,s in enumerate(sponsors): db.add(GameSponsor(game_id=game_id,sponsor_id=s.id,display_order=s.display_order if s.display_order is not None else i,created_at=now))
    await db.commit(); return await list_game_sponsors(db,club_id,game_id)
