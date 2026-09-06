"""M17-I Director-only production support diagnostics API."""

from fastapi import APIRouter, Depends

from app.auth.authorization import require_director
from app.auth.dependencies import require_current_user
from app.models.user import User
from app.services.support_diagnostics import build_support_diagnostics

router = APIRouter(prefix="/api/support", tags=["support"])


@router.get("/diagnostics")
async def support_diagnostics(
    current_user: User = Depends(require_current_user),
):
    """Return a read-only, secret-safe operational snapshot for Club Directors."""
    require_director(current_user)
    return await build_support_diagnostics()
