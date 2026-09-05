from pathlib import Path
from fastapi import APIRouter,Depends,Form,Request
from fastapi.responses import HTMLResponse,RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.services.auth_service import create_user_session,set_session_cookie
from app.services.invitation_service import InvitationInvalid,activate_invitation,activation_context
router=APIRouter();templates=Jinja2Templates(directory=str(Path(__file__).resolve().parents[2]/"templates"))
def invalid(request): return templates.TemplateResponse(request=request,name="auth/activate_invalid.html",context={},status_code=400)
@router.get("/activate",response_class=HTMLResponse)
async def page(request:Request,token:str="",db:AsyncSession=Depends(get_session)):
    try:i,club=await activation_context(db,token)
    except InvitationInvalid:return invalid(request)
    return templates.TemplateResponse(request=request,name="auth/activate.html",context={"token":token,"invitation":i,"club":club,"error":None})
@router.post("/activate",response_class=HTMLResponse)
async def submit(request:Request,token:str=Form(...),display_name:str=Form(""),password:str=Form(...),confirm_password:str=Form(...),db:AsyncSession=Depends(get_session)):
    try:i,club=await activation_context(db,token)
    except InvitationInvalid:return invalid(request)
    if password!=confirm_password:return templates.TemplateResponse(request=request,name="auth/activate.html",context={"token":token,"invitation":i,"club":club,"error":"Passwords do not match."},status_code=422)
    try:u=await activate_invitation(db,raw_token=token,password=password,display_name=display_name)
    except ValueError as e:return templates.TemplateResponse(request=request,name="auth/activate.html",context={"token":token,"invitation":i,"club":club,"error":str(e)},status_code=422)
    _,raw=await create_user_session(db,u);response=RedirectResponse("/games",303);set_session_cookie(response,raw);return response
