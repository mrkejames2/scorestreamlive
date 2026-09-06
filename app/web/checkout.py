from fastapi import APIRouter
from fastapi.responses import FileResponse
router=APIRouter()
@router.api_route("/checkout/success",methods=["GET","HEAD"])
async def checkout_success(): return FileResponse("static/checkout-success.html")
@router.api_route("/checkout/cancel",methods=["GET","HEAD"])
async def checkout_cancel(): return FileResponse("static/checkout-cancel.html")
