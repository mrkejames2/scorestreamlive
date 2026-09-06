from fastapi import APIRouter
from fastapi.responses import FileResponse
router=APIRouter()
@router.api_route("/signup",methods=["GET","HEAD"])
async def signup_page(): return FileResponse("static/signup.html")
