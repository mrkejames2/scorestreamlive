"""Public password recovery and authenticated password change routes."""
from pathlib import Path
from fastapi import APIRouter,Depends,Form,Request
from fastapi.responses import HTMLResponse,RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.config import settings
from app.database import get_session
from app.models.user import User
from app.services.password_recovery_service import PasswordChangeInvalid,PasswordResetInvalid,change_password,consume_password_reset,request_password_reset,resolve_password_reset

router=APIRouter()
templates=Jinja2Templates(directory=str(Path(__file__).resolve().parents[2]/"templates"))
GENERIC_FORGOT_MESSAGE="If an active ScoreStreamLive account exists for that email, a password-reset link has been sent."
GENERIC_INVALID_MESSAGE="This password-reset link is invalid or has expired. Request a new password-reset link."

@router.get("/forgot-password",response_class=HTMLResponse)
async def forgot_page(request:Request):
    return templates.TemplateResponse(request=request,name="auth/forgot_password.html",context={"message":None})

@router.post("/forgot-password",response_class=HTMLResponse)
async def forgot_submit(request:Request,email:str=Form(...),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request); await request_password_reset(db,email)
    return templates.TemplateResponse(request=request,name="auth/forgot_password.html",context={"message":GENERIC_FORGOT_MESSAGE})

@router.get("/reset-password",response_class=HTMLResponse)
async def reset_page(request:Request,token:str="",db:AsyncSession=Depends(get_session)):
    try: await resolve_password_reset(db,token)
    except PasswordResetInvalid:
        return templates.TemplateResponse(request=request,name="auth/reset_password_invalid.html",context={"message":GENERIC_INVALID_MESSAGE},status_code=400)
    return templates.TemplateResponse(request=request,name="auth/reset_password.html",context={"token":token,"error":None})

@router.post("/reset-password",response_class=HTMLResponse)
async def reset_submit(request:Request,token:str=Form(...),password:str=Form(...),password_confirm:str=Form(...),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request)
    if password!=password_confirm:
        return templates.TemplateResponse(request=request,name="auth/reset_password.html",context={"token":token,"error":"Passwords do not match."},status_code=422)
    try: await consume_password_reset(db,raw_token=token,password=password)
    except PasswordResetInvalid:
        return templates.TemplateResponse(request=request,name="auth/reset_password_invalid.html",context={"message":GENERIC_INVALID_MESSAGE},status_code=400)
    except ValueError as exc:
        return templates.TemplateResponse(request=request,name="auth/reset_password.html",context={"token":token,"error":str(exc)},status_code=422)
    return RedirectResponse(url="/login?password_reset=1",status_code=303)

@router.post("/account/change-password")
async def change_submit(request:Request,current_password:str=Form(...),new_password:str=Form(...),new_password_confirm:str=Form(...),current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    require_same_origin_mutation(request)
    if new_password!=new_password_confirm:return RedirectResponse(url="/account?password_error=mismatch",status_code=303)
    try:
        await change_password(db,user=current_user,current_password=current_password,new_password=new_password,current_session_token=request.cookies.get(settings.AUTH_SESSION_COOKIE_NAME))
    except PasswordChangeInvalid:return RedirectResponse(url="/account?password_error=current",status_code=303)
    except ValueError:return RedirectResponse(url="/account?password_error=policy",status_code=303)
    return RedirectResponse(url="/account?password_changed=1",status_code=303)
