"""Central commercial entitlement resolution for M18-A."""
import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.plan import Entitlement, PlanEntitlement
from app.models.subscription import Subscription


CREATE_GAMES = "CREATE_GAMES"
MANAGE_USERS = "MANAGE_USERS"
BROADCAST_OVERLAY = "BROADCAST_OVERLAY"
CUSTOM_OVERLAY_BRANDING = "CUSTOM_OVERLAY_BRANDING"

KNOWN_ENTITLEMENTS = frozenset(
    {
        CREATE_GAMES,
        MANAGE_USERS,
        BROADCAST_OVERLAY,
        CUSTOM_OVERLAY_BRANDING,
    }
)


def subscription_status_grants_paid_entitlements(status: str) -> bool:
    """Return the conservative M18-A lifecycle policy.

    ACTIVE grants paid entitlements. M18-H will explicitly define grace-period,
    cancellation-period, and recovery behavior before those states are used to
    alter customer access.
    """
    return status == "ACTIVE"


async def club_has_entitlement(
    session: AsyncSession,
    club_id: uuid.UUID,
    entitlement_code: str,
    *,
    legacy_default: bool = False,
) -> bool:
    """Resolve a Club capability without coupling product code to provider IDs.

    Existing pre-commercial Clubs may opt into an explicit compatibility
    default while M18 is rolled out. Callers must choose that default; there is
    no blanket "all legacy clubs get all paid features" behavior.
    """
    subscription_result = await session.execute(
        select(Subscription).where(Subscription.club_id == club_id)
    )
    subscription = subscription_result.scalar_one_or_none()

    if subscription is None:
        return legacy_default

    if not subscription_status_grants_paid_entitlements(subscription.status):
        return False

    entitlement_result = await session.execute(
        select(PlanEntitlement.enabled)
        .join(Entitlement, Entitlement.id == PlanEntitlement.entitlement_id)
        .where(
            PlanEntitlement.plan_id == subscription.plan_id,
            Entitlement.code == entitlement_code,
        )
    )
    enabled = entitlement_result.scalar_one_or_none()
    return bool(enabled)


async def require_club_entitlement(
    session: AsyncSession,
    club_id: uuid.UUID,
    entitlement_code: str,
    *,
    legacy_default: bool = False,
) -> None:
    """Raise PermissionError when the Club lacks a requested capability."""
    if not await club_has_entitlement(
        session,
        club_id,
        entitlement_code,
        legacy_default=legacy_default,
    ):
        raise PermissionError(
            f"Club is not entitled to capability {entitlement_code}"
        )
