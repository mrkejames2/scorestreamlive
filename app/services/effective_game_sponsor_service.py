"""M19-D presentation-safe effective Sponsor resolution."""
from datetime import datetime, timezone
from sqlalchemy import or_, select
from app.models.game_sponsor import GameSponsor
from app.models.sponsor import Sponsor

async def get_effective_game_sponsors(db, game_id, club_id):
    now = datetime.now(timezone.utc)
    result = await db.execute(
        select(GameSponsor, Sponsor).join(Sponsor, Sponsor.id == GameSponsor.sponsor_id)
        .where(GameSponsor.game_id == game_id, Sponsor.club_id == club_id,
               Sponsor.is_active.is_(True), Sponsor.artwork_url.is_not(None), Sponsor.artwork_url != "",
               or_(Sponsor.starts_at.is_(None), Sponsor.starts_at <= now),
               or_(Sponsor.ends_at.is_(None), Sponsor.ends_at >= now))
        .order_by(GameSponsor.display_order, Sponsor.display_order, Sponsor.name, Sponsor.id)
    )
    return [{"id": str(s.id), "name": s.name, "artwork_url": s.artwork_url,
             "website_url": s.website_url, "display_order": a.display_order} for a, s in result.all()]
