"""Authoritative public Club-branding projection for M18-G3."""
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from app.services.club_branding_service import get_club_branding
from app.services.entitlement_service import CUSTOM_OVERLAY_BRANDING, effective_club_has_entitlement

DEFAULT_PRIMARY = "#2A77FF"
DEFAULT_SECONDARY = "#FFFFFF"

def _normalized_color(value: str | None, fallback: str) -> str:
    raw = (value or "").strip()
    if len(raw) == 7 and raw.startswith("#"):
        try:
            int(raw[1:], 16)
            return raw.upper()
        except ValueError:
            pass
    return fallback

async def get_effective_club_branding(db: AsyncSession, club_id: uuid.UUID) -> dict:
    entitled = await effective_club_has_entitlement(db, club_id, CUSTOM_OVERLAY_BRANDING)
    if not entitled:
        return {"enabled": False, "display_name": "ScoreStreamLive", "short_name": "SSL", "logo_url": None, "primary_color": DEFAULT_PRIMARY, "secondary_color": DEFAULT_SECONDARY}
    branding = await get_club_branding(db, club_id)
    if branding is None:
        return {"enabled": False, "display_name": "ScoreStreamLive", "short_name": "SSL", "logo_url": None, "primary_color": DEFAULT_PRIMARY, "secondary_color": DEFAULT_SECONDARY}
    return {
        "enabled": True,
        "display_name": (branding.display_name or "").strip() or "ScoreStreamLive",
        "short_name": (branding.short_name or "").strip() or "SSL",
        "logo_url": branding.logo_url,
        "primary_color": _normalized_color(branding.primary_color, DEFAULT_PRIMARY),
        "secondary_color": _normalized_color(branding.secondary_color, DEFAULT_SECONDARY),
    }
