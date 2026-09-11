"""Authenticated billing-management API."""

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.dependencies import require_current_user
from app.auth.security import require_same_origin_mutation
from app.billing.factory import get_billing_provider
from app.billing.provider import BillingProvider
from app.database import get_session
from app.models.user import User
from app.services.billing_management_service import (
    BillingManagementRejected,
    create_billing_portal,
)

router = APIRouter(prefix="/api/billing", tags=["billing-management"])


class PortalResponse(BaseModel):
    url: str


@router.post("/portal", response_model=PortalResponse)
async def portal(
    request: Request,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
    provider: BillingProvider = Depends(get_billing_provider),
):
    require_same_origin_mutation(request)

    try:
        result = await create_billing_portal(
            db,
            current_user=current_user,
            provider=provider,
        )
    except BillingManagementRejected as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail=str(exc),
        ) from exc

    return PortalResponse(url=result.portal_url)
