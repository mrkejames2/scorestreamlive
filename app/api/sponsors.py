import uuid
from fastapi import APIRouter, Depends, File, HTTPException, Response, UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.database import get_session
from app.models.user import User
from app.schemas.sponsor import SponsorCreate, SponsorResponse, SponsorUpdate
from app.services.sponsor_service import create_sponsor, delete_sponsor, get_sponsor, list_sponsors, set_sponsor_artwork_url
from app.services.sponsor_artwork_storage import SponsorArtworkTooLargeError, SponsorArtworkUnsupportedTypeError, delete_filename, filename_from_artwork_url, path_for_filename, save_sponsor_artwork

router=APIRouter(tags=["sponsors"])

def _require_director_club(user:User)->uuid.UUID:
    if user.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if user.club_role!="DIRECTOR": raise HTTPException(status_code=403,detail="Director access required.")
    return user.club_id

@router.get("/api/account/sponsors",response_model=list[SponsorResponse])
async def sponsors(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    return await list_sponsors(db,_require_director_club(current_user))

@router.post("/api/account/sponsors",response_model=SponsorResponse,status_code=201)
async def create(data:SponsorCreate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    return await create_sponsor(db,_require_director_club(current_user),data)

@router.get("/api/account/sponsors/{sponsor_id}",response_model=SponsorResponse)
async def retrieve(sponsor_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    return await get_sponsor(db,_require_director_club(current_user),sponsor_id)

@router.patch("/api/account/sponsors/{sponsor_id}",response_model=SponsorResponse)
async def update(sponsor_id:uuid.UUID,data:SponsorUpdate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    return await update_sponsor(db,_require_director_club(current_user),sponsor_id,data)

@router.delete("/api/account/sponsors/{sponsor_id}",status_code=204)
async def remove(sponsor_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); sponsor=await get_sponsor(db,club_id,sponsor_id)
    filename=filename_from_artwork_url(sponsor.artwork_url); await delete_sponsor(db,club_id,sponsor_id); delete_filename(filename)
    return Response(status_code=204)

@router.post("/api/account/sponsors/{sponsor_id}/artwork",response_model=SponsorResponse)
async def upload_artwork(sponsor_id:uuid.UUID,artwork:UploadFile=File(...),current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); sponsor=await get_sponsor(db,club_id,sponsor_id)
    previous=filename_from_artwork_url(sponsor.artwork_url); new=None
    try: new=await save_sponsor_artwork(club_id=club_id,upload=artwork)
    except SponsorArtworkTooLargeError as exc: raise HTTPException(status_code=413,detail=str(exc)) from exc
    except SponsorArtworkUnsupportedTypeError as exc: raise HTTPException(status_code=415,detail=str(exc)) from exc
    finally: await artwork.close()
    try: updated=await set_sponsor_artwork_url(db,club_id,sponsor_id,f"/api/sponsor-assets/{new}")
    except Exception: delete_filename(new); raise
    if previous and previous!=new: delete_filename(previous)
    return updated

@router.delete("/api/account/sponsors/{sponsor_id}/artwork",status_code=204)
async def remove_artwork(sponsor_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); sponsor=await get_sponsor(db,club_id,sponsor_id)
    filename=filename_from_artwork_url(sponsor.artwork_url); await set_sponsor_artwork_url(db,club_id,sponsor_id,None); delete_filename(filename)
    return Response(status_code=204)

@router.get("/api/sponsor-assets/{filename}")
async def retrieve_asset(filename:str):
    try: path=path_for_filename(filename)
    except FileNotFoundError: raise HTTPException(status_code=404,detail="Sponsor asset not found")
    return FileResponse(path,headers={"Cache-Control":"public, max-age=31536000, immutable"})
