#!/usr/bin/env python3
"""Reprocess one already-verified persisted billing event by application event UUID."""
import argparse
import asyncio
import uuid

from app.billing.factory import get_billing_provider
from app.database import AsyncSessionLocal
from app.services.billing_event_service import reprocess_persisted_event

async def main(event_id: str) -> None:
    parsed = uuid.UUID(event_id)
    async with AsyncSessionLocal() as db:
        result = await reprocess_persisted_event(db, billing_event_id=parsed, provider=get_billing_provider())
        print(f"{parsed}: {result}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("billing_event_id")
    asyncio.run(main(parser.parse_args().billing_event_id))
