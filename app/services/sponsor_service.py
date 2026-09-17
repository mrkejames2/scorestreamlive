import uuid
from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.sponsor import Sponsor
from app.schemas.sponsor import SponsorCreate, SponsorUpdate

async def list_sponsors(db: AsyncSession, club_id: uuid.UUID):
    result = await db.execute(
        select(Sponsor).where(Sponsor.club_id == club_id)
        .order_by(Sponsor.display_order, Sponsor.name, Sponsor.id)
    )
    return list(result.scalars().all())

async def get_sponsor(db: AsyncSession, club_id: uuid.UUID, sponsor_id: uuid.UUID) -> Sponsor:
    result = await db.execute(
        select(Sponsor).where(Sponsor.id == sponsor_id, Sponsor.club_id == club_id)
    )
    sponsor = result.scalar_one_or_none()
    if sponsor is None:
        raise HTTPException(status_code=404, detail="Sponsor not found")
    return sponsor

async def create_sponsor(db: AsyncSession, club_id: uuid.UUID, data: SponsorCreate) -> Sponsor:
    values=data.model_dump()
    if values.get("website_url") is not None: values["website_url"]=str(values["website_url"])
    sponsor=Sponsor(club_id=club_id, **values)
    db.add(sponsor); await db.commit(); await db.refresh(sponsor); return sponsor

async def update_sponsor(db: AsyncSession, club_id: uuid.UUID, sponsor_id: uuid.UUID, data: SponsorUpdate) -> Sponsor:
    sponsor=await get_sponsor(db,club_id,sponsor_id)
    values=data.model_dump(exclude_unset=True)
    if values.get("website_url") is not None: values["website_url"]=str(values["website_url"])
    for field,value in values.items(): setattr(sponsor,field,value)
    if sponsor.starts_at and sponsor.ends_at and sponsor.ends_at < sponsor.starts_at:
        raise HTTPException(status_code=422,detail="ends_at must be greater than or equal to starts_at")
    await db.commit(); await db.refresh(sponsor); return sponsor

async def set_sponsor_artwork_url(db: AsyncSession, club_id: uuid.UUID, sponsor_id: uuid.UUID, artwork_url: str|None) -> Sponsor:
    sponsor=await get_sponsor(db,club_id,sponsor_id)
    sponsor.artwork_url=artwork_url; await db.commit(); await db.refresh(sponsor); return sponsor

async def delete_sponsor(db: AsyncSession, club_id: uuid.UUID, sponsor_id: uuid.UUID) -> Sponsor:
    sponsor=await get_sponsor(db,club_id,sponsor_id)
    await db.delete(sponsor); await db.commit(); return sponsor
