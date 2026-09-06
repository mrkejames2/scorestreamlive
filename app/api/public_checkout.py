"""Public hosted checkout boundary."""
import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.billing.factory import get_billing_provider
from app.billing.provider import BillingProvider
from app.config import settings
from app.database import get_session
from app.services.checkout_service import CheckoutRejected, create_checkout, list_checkout_plans

router = APIRouter(prefix="/api/public/checkout", tags=["public-checkout"])


class CheckoutRequestBody(BaseModel):
    signup_intent_id: uuid.UUID
    plan_code: str = Field(min_length=1, max_length=64)


class CheckoutResponse(BaseModel):
    checkout_url: str


class PublicPlan(BaseModel):
    code: str
    name: str
    description: str | None
    currency: str
    billing_interval: str
    unit_amount_minor: int


@router.get("/plans", response_model=list[PublicPlan])
async def plans(db: AsyncSession = Depends(get_session)):
    provider_name = settings.BILLING_PROVIDER.strip().lower()
    rows = await list_checkout_plans(db, provider_name)
    return [
        PublicPlan(
            code=plan.code,
            name=plan.name,
            description=plan.description,
            currency=price.currency,
            billing_interval=price.billing_interval,
            unit_amount_minor=price.unit_amount_minor,
        )
        for plan, price in rows
    ]


@router.post("", response_model=CheckoutResponse)
async def checkout(
    data: CheckoutRequestBody,
    db: AsyncSession = Depends(get_session),
    provider: BillingProvider = Depends(get_billing_provider),
):
    try:
        result = await create_checkout(
            db,
            signup_intent_id=data.signup_intent_id,
            plan_code=data.plan_code,
            provider=provider,
        )
    except CheckoutRejected as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return CheckoutResponse(checkout_url=result.checkout_url)
