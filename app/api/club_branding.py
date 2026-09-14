import uuid
from fastapi import APIRouter,Depends,File,HTTPException,Response,UploadFile
from fastapi.responses import FileResponse
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.auth.entitlements import require_entitlement
from app.database import get_session
from app.models.user import User
from app.schemas.club_branding import ClubBrandingResponse,ClubBrandingUpdate
from app.services.club_branding_service import get_club_branding,set_club_branding_logo_url,update_club_branding
from app.services.club_branding_storage import ClubBrandingTooLargeError,ClubBrandingUnsupportedTypeError,delete_filename,filename_from_logo_url,path_for_filename,save_club_branding_logo
from app.services.entitlement_service import CUSTOM_OVERLAY_BRANDING
from app.services.effective_branding_service import get_effective_club_branding
router=APIRouter(tags=["club-branding"])
def _require_director_club(user:User)->uuid.UUID:
    if user.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if user.club_role!="DIRECTOR": raise HTTPException(status_code=403,detail="Director access required.")
    return user.club_id
@router.get("/api/account/effective-branding")
async def effective_account_branding(
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    if current_user.club_id is None:
        raise HTTPException(
            status_code=409,
            detail="User is not assigned to a Club",
        )

    return await get_effective_club_branding(
        db,
        current_user.club_id,
    )


@router.get("/api/account/branding",response_model=ClubBrandingResponse)
async def branding(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); await require_entitlement(db,club_id,CUSTOM_OVERLAY_BRANDING)
    existing=await get_club_branding(db,club_id); return existing or ClubBrandingResponse()
@router.patch("/api/account/branding",response_model=ClubBrandingResponse)
async def update_branding(data:ClubBrandingUpdate,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); await require_entitlement(db,club_id,CUSTOM_OVERLAY_BRANDING); return await update_club_branding(db,club_id,data)
@router.post("/api/account/branding/logo",response_model=ClubBrandingResponse)
async def upload_branding_logo(logo:UploadFile=File(...),current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); await require_entitlement(db,club_id,CUSTOM_OVERLAY_BRANDING)
    current=await get_club_branding(db,club_id); previous=filename_from_logo_url(current.logo_url) if current else None; new=None
    try: new=await save_club_branding_logo(club_id=club_id,upload=logo)
    except ClubBrandingTooLargeError as exc: raise HTTPException(status_code=413,detail=str(exc)) from exc
    except ClubBrandingUnsupportedTypeError as exc: raise HTTPException(status_code=415,detail=str(exc)) from exc
    finally: await logo.close()
    url=f"/api/club-branding-assets/{new}"
    try: updated=await set_club_branding_logo_url(db,club_id,url)
    except Exception: delete_filename(new); raise
    if previous and previous!=new: delete_filename(previous)
    return updated
@router.delete("/api/account/branding/logo",status_code=204)
async def delete_branding_logo(current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    club_id=_require_director_club(current_user); await require_entitlement(db,club_id,CUSTOM_OVERLAY_BRANDING)
    current=await get_club_branding(db,club_id)
    if current is None or not current.logo_url: return Response(status_code=204)
    filename=filename_from_logo_url(current.logo_url); await set_club_branding_logo_url(db,club_id,None); delete_filename(filename); return Response(status_code=204)
@router.get("/api/club-branding-assets/{filename}")
async def retrieve_branding_asset(filename:str):
    try: path=path_for_filename(filename)
    except FileNotFoundError: raise HTTPException(status_code=404,detail="Club branding asset not found")
    return FileResponse(path,headers={"Cache-Control":"public, max-age=31536000, immutable"})
