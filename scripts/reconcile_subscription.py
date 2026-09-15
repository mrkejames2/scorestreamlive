#!/usr/bin/env python3
"""Operator-only M18-H reconciliation for one provider subscription."""
import argparse
import asyncio

from sqlalchemy import select

from app.billing.factory import get_billing_provider
from app.database import AsyncSessionLocal
from app.models.billing_external_reference import BillingExternalReference
from app.services.subscription_lifecycle_service import apply_subscription_snapshot

async def main(external_subscription_id: str):
    provider = get_billing_provider()
    snapshot = await provider.retrieve_subscription(external_subscription_id)
    async with AsyncSessionLocal() as db:
        ref = await db.scalar(select(BillingExternalReference).where(
            BillingExternalReference.provider == provider.name,
            BillingExternalReference.resource_type == "subscription",
            BillingExternalReference.external_id == external_subscription_id,
        ))
        if ref is None:
            raise SystemExit("No local subscription reference found.")
        subscription, applied = await apply_subscription_snapshot(
            db, provider=provider.name, snapshot=snapshot,
            event_created_at=None, event_id=f"manual-reconcile:{external_subscription_id}",
        )
        await db.commit()
        print(f"subscription={subscription.id} status={subscription.status} applied={applied}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("external_subscription_id")
    args = parser.parse_args()
    asyncio.run(main(args.external_subscription_id))
