import uuid
from fastapi import APIRouter,Depends,HTTPException,status
from pydantic import BaseModel,Field
from sqlalchemy.ext.asyncio import AsyncSession
from app.database import get_session
from app.services.signup_service import SignupRejected,create_or_resume_signup
router=APIRouter(prefix="/api/public/signup",tags=["public-signup"])
class SignupRequest(BaseModel):
    email:str=Field(min_length=3,max_length=320)
    first_name:str=Field(min_length=1,max_length=100)
    last_name:str=Field(min_length=1,max_length=100)
    organization_name:str=Field(min_length=1,max_length=180)
class SignupResponse(BaseModel):
    signup_intent_id:uuid.UUID
    status:str
@router.post("",response_model=SignupResponse,status_code=status.HTTP_201_CREATED)
async def signup(data:SignupRequest,db:AsyncSession=Depends(get_session)):
    try:
        i=await create_or_resume_signup(db,email=data.email,first_name=data.first_name,last_name=data.last_name,organization_name=data.organization_name)
    except SignupRejected as e: raise HTTPException(409,str(e)) from e
    except ValueError as e: raise HTTPException(422,str(e)) from e
    return SignupResponse(signup_intent_id=i.id,status=i.status)
