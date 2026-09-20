"""M19-G server-authoritative sponsor appearance tracking/reporting."""
import uuid
from datetime import datetime,timezone
from sqlalchemy import select
from app.models.game import Game
from app.models.game_lifecycle import GameLifecycle
from app.models.game_sponsor_presentation import GameSponsorPresentation
from app.models.game_sponsor_tracking_state import GameSponsorTrackingState
from app.models.sponsor import Sponsor
from app.models.sponsor_impression import SponsorImpression
from app.services.effective_game_sponsor_service import get_effective_game_sponsors
TRACKED_PHASES={"first_half","second_half"}
def _now():return datetime.now(timezone.utc)
def _aware(v):return v if v.tzinfo else v.replace(tzinfo=timezone.utc)
def _seconds(a,b):return max(0,int((_aware(b)-_aware(a)).total_seconds()))
async def _state(db,gid,now):
    row=await db.get(GameSponsorTrackingState,gid)
    if row is None:
        row=GameSponsorTrackingState(game_id=gid,active_sponsor_id=None,active_impression_id=None,tracking_active=False,last_reconciled_at=now,version=1,created_at=now,updated_at=now);db.add(row);await db.flush()
    return row
async def _close(db,state,at):
    if state.active_impression_id:
        imp=await db.get(SponsorImpression,state.active_impression_id)
        if imp and imp.ended_at is None:imp.ended_at=at;imp.duration_seconds=_seconds(imp.started_at,at)
    state.active_sponsor_id=None;state.active_impression_id=None
async def _open(db,game,state,sid,at,trigger):
    if sid is None:return
    sponsor=await db.get(Sponsor,sid)
    if sponsor is None:return
    imp=SponsorImpression(id=uuid.uuid4(),club_id=game.club_id,game_id=game.id,sponsor_id=sid,sponsor_name=sponsor.name,started_at=at,ended_at=None,duration_seconds=None,trigger=trigger,created_at=at);db.add(imp);await db.flush();state.active_sponsor_id=sid;state.active_impression_id=imp.id
async def reconcile_sponsor_tracking(db,game_id,at=None,trigger="recovery",commit=True):
    at=at or _now();game=await db.get(Game,game_id)
    if game is None:return None
    lifecycle=(await db.execute(select(GameLifecycle).where(GameLifecycle.game_id==game_id))).scalar_one_or_none()
    p=await db.get(GameSponsorPresentation,game_id);state=await _state(db,game_id,at)
    if not lifecycle or lifecycle.phase not in TRACKED_PHASES or game.archived_at is not None:
        await _close(db,state,at);state.tracking_active=False;state.last_reconciled_at=at;state.version+=1;state.updated_at=at
        if commit:await db.commit()
        return state
    sponsors=await get_effective_game_sponsors(db,game.id,game.club_id);ids=[s["id"] for s in sponsors]
    visible=bool(p.visible) if p else True;rotating=bool(p.rotation_enabled) if p else True;interval=int(p.rotation_interval_seconds) if p else 10
    base=p.current_sponsor_id if p and p.current_sponsor_id in ids else (ids[0] if ids else None);anchor=_aware(p.updated_at) if p else at
    cursor=min(max(_aware(state.last_reconciled_at),anchor),at)
    def sponsor_at(moment):
        if not visible or not ids or base is None:return None
        if not rotating or len(ids)<2:return base
        pos=int(max(0,(_aware(moment)-anchor).total_seconds())//interval)%len(ids);return ids[(ids.index(base)+pos)%len(ids)]
    cur=sponsor_at(cursor)
    if state.active_sponsor_id!=cur:await _close(db,state,cursor);await _open(db,game,state,cur,cursor,trigger)
    if rotating and visible and len(ids)>1 and at>cursor:
        ec=max(0,(cursor-anchor).total_seconds());nb=anchor.timestamp()+(int(ec//interval)+1)*interval
        while nb<=at.timestamp():
            boundary=datetime.fromtimestamp(nb,tz=timezone.utc);nxt=sponsor_at(boundary)
            if state.active_sponsor_id!=nxt:await _close(db,state,boundary);await _open(db,game,state,nxt,boundary,"rotation")
            nb+=interval
    state.tracking_active=True;state.last_reconciled_at=at;state.version+=1;state.updated_at=at
    if commit:await db.commit()
    return state
async def sponsor_report(db,game_id,at=None):
    at=at or _now();await reconcile_sponsor_tracking(db,game_id,at=at,trigger="report",commit=True);game=await db.get(Game,game_id)
    lifecycle=(await db.execute(select(GameLifecycle).where(GameLifecycle.game_id==game_id))).scalar_one_or_none()
    rows=(await db.execute(select(SponsorImpression).where(SponsorImpression.game_id==game_id).order_by(SponsorImpression.started_at))).scalars().all();totals={}
    for row in rows:
        sec=row.duration_seconds if row.duration_seconds is not None else _seconds(row.started_at,at);key=(row.sponsor_id,row.sponsor_name);item=totals.setdefault(key,{"impressions":0,"display_seconds":0});item["impressions"]+=1;item["display_seconds"]+=sec

    phase=lifecycle.phase if lifecycle else "pregame";status="complete" if phase=="full_time" else ("live" if phase in TRACKED_PHASES else "not_tracking")
    return {"game_id":str(game.id),"tracking_status":status,"tracked_seconds":sum(v["display_seconds"] for v in totals.values()),"sponsors":[{"sponsor_id":str(k[0]) if k[0] is not None else None,"name":k[1],"tracked_appearances":v["impressions"],"display_seconds":v["display_seconds"]} for k,v in totals.items()]}
