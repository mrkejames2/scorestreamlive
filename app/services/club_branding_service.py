import uuid
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.club_branding import ClubBranding
from app.schemas.club_branding import ClubBrandingUpdate
async def get_club_branding(db:AsyncSession,club_id:uuid.UUID)->ClubBranding|None:
    r=await db.execute(select(ClubBranding).where(ClubBranding.club_id==club_id)); return r.scalar_one_or_none()
async def get_or_create_club_branding(db:AsyncSession,club_id:uuid.UUID)->ClubBranding:
    b=await get_club_branding(db,club_id)
    if b is not None: return b
    b=ClubBranding(club_id=club_id); db.add(b); await db.flush(); return b
async def update_club_branding(db:AsyncSession,club_id:uuid.UUID,data:ClubBrandingUpdate)->ClubBranding:
    b=await get_or_create_club_branding(db,club_id)
    for field,value in data.model_dump(exclude_unset=True).items(): setattr(b,field,value)
    await db.commit(); await db.refresh(b); return b
async def set_club_branding_logo_url(db:AsyncSession,club_id:uuid.UUID,logo_url:str|None)->ClubBranding:
    b=await get_or_create_club_branding(db,club_id); b.logo_url=logo_url; await db.commit(); await db.refresh(b); return b
