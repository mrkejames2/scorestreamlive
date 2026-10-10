from datetime import datetime, timezone
from fastapi import HTTPException
from sqlalchemy import select, delete, update
from app.models.game_announcement import GameAnnouncement, GameAnnouncementState

def _utc():
    return datetime.now(timezone.utc)

async def get_state(db, game_id):
    state = await db.get(GameAnnouncementState, game_id)
    items = (await db.execute(select(GameAnnouncement).where(GameAnnouncement.game_id == game_id).order_by(GameAnnouncement.position, GameAnnouncement.id))).scalars().all()
    return {
        "game_id": str(game_id),
        "title": state.title if state else "SENIOR NIGHT",
        "version": state.version if state else 0,
        "visible": bool(state and state.visible),
        "active_id": str(state.active_id) if state and state.active_id else None,
        "items": [{"id": str(i.id), "number": i.number, "name": i.name, "subtitle": i.subtitle, "position": i.position} for i in items],
    }

async def _locked_state(db, game_id, expected):
    state = (await db.execute(select(GameAnnouncementState).where(GameAnnouncementState.game_id == game_id).with_for_update())).scalar_one_or_none()
    if state is None:
        # Serialize first creation using a lock on the parent game, then re-check.
        from app.models.game import Game
        await db.execute(select(Game.id).where(Game.id == game_id).with_for_update())
        state = (await db.execute(select(GameAnnouncementState).where(GameAnnouncementState.game_id == game_id).with_for_update())).scalar_one_or_none()
        if state is None:
            state = GameAnnouncementState(game_id=game_id, version=0, title="SENIOR NIGHT", visible=False, updated_at=_utc())
            db.add(state)
            await db.flush()
    if state.version != expected:
        raise HTTPException(409, "Announcement state changed; refresh and retry")
    return state

async def save_list(db, game_id, payload):
    state = await _locked_state(db, game_id, payload.expected_version)
    state.title = payload.title.strip()
    state.active_id = None
    state.visible = False
    # Clear active reference before deleting existing rows.
    await db.flush()
    await db.execute(delete(GameAnnouncement).where(GameAnnouncement.game_id == game_id))
    await db.flush()
    for position, item in enumerate(payload.items):
        db.add(GameAnnouncement(game_id=game_id, position=position, number=item.number.strip(), name=item.name.strip(), subtitle=item.subtitle.strip(), created_at=_utc()))
    state.version += 1
    state.updated_at = _utc()
    await db.commit()
    return await get_state(db, game_id)

async def command(db, game_id, payload):
    state = await _locked_state(db, game_id, payload.expected_version)
    items = (await db.execute(select(GameAnnouncement).where(GameAnnouncement.game_id == game_id).order_by(GameAnnouncement.position, GameAnnouncement.id))).scalars().all()
    ids = [str(i.id) for i in items]
    action = payload.action
    if action == "hide":
        state.visible = False
    elif action in ("show", "next", "previous"):
        if not items:
            raise HTTPException(409, "Add announcements first")
        if action == "show":
            target = payload.item_id or (str(state.active_id) if state.active_id else ids[0])
            if target not in ids:
                raise HTTPException(422, "Invalid announcement item")
            state.active_id = items[ids.index(target)].id
        else:
            current = ids.index(str(state.active_id)) if state.active_id and str(state.active_id) in ids else (-1 if action == "next" else 0)
            index = min(len(ids)-1, current+1) if action == "next" else max(0, current-1)
            state.active_id = items[index].id
        state.visible = True
    else:
        raise HTTPException(422, "Unsupported action")
    state.version += 1
    state.updated_at = _utc()
    await db.commit()
    return await get_state(db, game_id)
