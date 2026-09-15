"""Central commercial entitlement resolution."""
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.models.plan import Entitlement, PlanEntitlement
from app.models.subscription import Subscription

CREATE_GAMES = "CREATE_GAMES"
MANAGE_USERS = "MANAGE_USERS"
BROADCAST_OVERLAY = "BROADCAST_OVERLAY"
CUSTOM_OVERLAY_BRANDING = "CUSTOM_OVERLAY_BRANDING"

KNOWN_ENTITLEMENTS = frozenset({
    CREATE_GAMES, MANAGE_USERS, BROADCAST_OVERLAY, CUSTOM_OVERLAY_BRANDING,
})

LEGACY_ENTITLEMENT_DEFAULTS = {
    CREATE_GAMES: True, MANAGE_USERS: True, BROADCAST_OVERLAY: True,
    CUSTOM_OVERLAY_BRANDING: False,
}

def subscription_grants_paid_entitlements(subscription: Subscription, *, now=None) -> bool:
    """M18-H lifecycle policy.

    ACTIVE remains entitled, including cancellation pending at period end.
    PAST_DUE receives a bounded grace window from current_period_end. Terminal
    states never grant paid capabilities. Stored customer configuration is not
    changed by this decision.
    """
    if subscription.status == "ACTIVE":
        return True
    if subscription.status != "PAST_DUE" or subscription.current_period_end is None:
        return False
    now = now or datetime.now(timezone.utc)
    end = subscription.current_period_end
    if end.tzinfo is None:
        end = end.replace(tzinfo=timezone.utc)
    grace_end = end + timedelta(days=settings.BILLING_PAST_DUE_GRACE_DAYS)
    return now <= grace_end

def subscription_status_grants_paid_entitlements(status: str) -> bool:
    """Compatibility helper for callers/tests that only possess a status."""
    return status == "ACTIVE"

async def club_has_entitlement(
    session: AsyncSession, club_id: uuid.UUID, entitlement_code: str, *,
    legacy_default: bool = False,
) -> bool:
    subscription = await session.scalar(
        select(Subscription).where(Subscription.club_id == club_id)
    )
    if subscription is None:
        return legacy_default
    if not subscription_grants_paid_entitlements(subscription):
        return False
    enabled = await session.scalar(
        select(PlanEntitlement.enabled)
        .join(Entitlement, Entitlement.id == PlanEntitlement.entitlement_id)
        .where(
            PlanEntitlement.plan_id == subscription.plan_id,
            Entitlement.code == entitlement_code,
        )
    )
    return bool(enabled)

async def require_club_entitlement(
    session: AsyncSession, club_id: uuid.UUID, entitlement_code: str, *,
    legacy_default: bool = False,
) -> None:
    if not await club_has_entitlement(
        session, club_id, entitlement_code, legacy_default=legacy_default
    ):
        raise PermissionError(f"Club is not entitled to capability {entitlement_code}")

async def effective_club_has_entitlement(
    session: AsyncSession, club_id: uuid.UUID, entitlement_code: str
) -> bool:
    if entitlement_code not in KNOWN_ENTITLEMENTS:
        return False
    return await club_has_entitlement(
        session, club_id, entitlement_code,
        legacy_default=LEGACY_ENTITLEMENT_DEFAULTS.get(entitlement_code, False),
    )

async def require_effective_club_entitlement(
    session: AsyncSession, club_id: uuid.UUID, entitlement_code: str
) -> None:
    if not await effective_club_has_entitlement(session, club_id, entitlement_code):
        raise PermissionError(f"Club is not entitled to capability {entitlement_code}")

async def effective_club_entitlements(
    session: AsyncSession, club_id: uuid.UUID
) -> dict[str, bool]:
    return {
        code: await effective_club_has_entitlement(session, club_id, code)
        for code in sorted(KNOWN_ENTITLEMENTS)
    }
