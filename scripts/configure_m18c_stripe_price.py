#!/usr/bin/env python3
"""Create/update one internal Plan -> Stripe Price mapping. No payment data is created."""
import argparse, asyncio
from sqlalchemy import select
from app.database import AsyncSessionLocal
from app.models.billing_price_reference import BillingPriceReference
from app.models.plan import Plan

async def main(args):
    async with AsyncSessionLocal() as db:
        plan=await db.scalar(select(Plan).where(Plan.code==args.plan_code))
        if plan is None:
            plan=Plan(code=args.plan_code,name=args.plan_name,description=args.description,is_active=True); db.add(plan); await db.flush()
        else:
            plan.name=args.plan_name; plan.description=args.description; plan.is_active=True
        ref=await db.scalar(select(BillingPriceReference).where(BillingPriceReference.provider=="stripe",BillingPriceReference.external_price_id==args.stripe_price_id))
        if ref is None:
            ref=BillingPriceReference(plan_id=plan.id,provider="stripe",external_price_id=args.stripe_price_id,currency=args.currency.lower(),billing_interval=args.interval,unit_amount_minor=args.amount_minor,is_active=True); db.add(ref)
        else:
            ref.plan_id=plan.id; ref.currency=args.currency.lower(); ref.billing_interval=args.interval; ref.unit_amount_minor=args.amount_minor; ref.is_active=True
        await db.commit(); print(f"Configured {plan.code} -> stripe:{args.stripe_price_id}")

if __name__=="__main__":
    p=argparse.ArgumentParser(); p.add_argument("--plan-code",required=True); p.add_argument("--plan-name",required=True); p.add_argument("--description",default=None); p.add_argument("--stripe-price-id",required=True); p.add_argument("--amount-minor",required=True,type=int); p.add_argument("--currency",default="usd"); p.add_argument("--interval",choices=["month","year"],required=True); asyncio.run(main(p.parse_args()))
