"""Club-scoped Team REST API routes."""

import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import can_manage_team, deny_not_found
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.user import User
from app.schemas.player import PlayerResponse
from app.schemas.team import TeamCreate, TeamUpdate, TeamResponse
from app.services.player_service import get_team_players
from app.services.team_logo_storage import (
    TeamLogoTooLargeError,
    TeamLogoUnsupportedTypeError,
    delete_filename,
    filename_from_logo_url,
    save_team_logo,
)
from app.services.team_service import (
    create_team,
    get_team,
    list_teams,
    set_team_logo_url,
    update_team,
)

router = APIRouter(prefix="/api/teams", tags=["teams"])


def _require_club(user: User) -> uuid.UUID:
    if user.club_id is None:
        raise HTTPException(status_code=409, detail="User is not assigned to a Club")
    return user.club_id


@router.post("", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
async def create(
    data: TeamCreate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    if current_user.club_role not in {ClubRole.DIRECTOR.value, ClubRole.MANAGER.value}:
        raise HTTPException(status_code=403, detail="Insufficient permission")
    return await create_team(db, data, _require_club(current_user))


@router.get("", response_model=list[TeamResponse])
async def list_all(
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    return await list_teams(db, _require_club(current_user))


@router.post("/{team_id}/logo", response_model=TeamResponse)
async def upload_logo(
    team_id: uuid.UUID,
    logo: UploadFile = File(...),
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or not await can_manage_team(db, current_user, team):
        deny_not_found("Team")

    previous_filename = filename_from_logo_url(team.logo_url)
    new_filename = None
    try:
        new_filename = await save_team_logo(team_id=team_id, upload=logo)
    except TeamLogoTooLargeError as exc:
        raise HTTPException(status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, detail=str(exc))
    except TeamLogoUnsupportedTypeError as exc:
        raise HTTPException(status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE, detail=str(exc))
    finally:
        await logo.close()

    logo_url = f"/api/team-logos/{new_filename}"
    try:
        updated = await set_team_logo_url(db, team_id, logo_url)
    except Exception:
        delete_filename(new_filename)
        raise

    if not updated:
        delete_filename(new_filename)
        deny_not_found("Team")

    if previous_filename and previous_filename != new_filename:
        delete_filename(previous_filename)
    return updated


@router.get("/{team_id}/players", response_model=list[PlayerResponse])
async def list_players(
    team_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or team.club_id != _require_club(current_user):
        deny_not_found("Team")
    return await get_team_players(db, team_id)


@router.get("/{team_id}", response_model=TeamResponse)
async def retrieve(
    team_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or team.club_id != _require_club(current_user):
        deny_not_found("Team")
    return team


@router.patch("/{team_id}", response_model=TeamResponse)
async def update(
    team_id: uuid.UUID,
    data: TeamUpdate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or not await can_manage_team(db, current_user, team):
        deny_not_found("Team")
    updated = await update_team(db, team_id, data)
    if not updated:
        deny_not_found("Team")
    return updated
