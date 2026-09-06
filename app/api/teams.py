"""Club- and role-scoped Team REST API routes for M15-D."""

import uuid

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Query,
    Response,
    UploadFile,
    status,
)
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import (
    can_manage_team,
    can_view_team,
    deny_not_found,
    visible_team_ids,
)
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.team_manager import TeamManager
from app.models.user import User
from app.schemas.player import PlayerResponse
from app.schemas.team import (
    TeamCreate,
    TeamResponse,
    TeamUpdate,
)
from app.services.player_service import get_team_players
from app.services.resource_lifecycle_service import LifecycleConflict, archive_team, hard_delete_team, restore_team
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
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="User is not assigned to a Club",
        )
    return user.club_id


@router.post(
    "",
    response_model=TeamResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create(
    data: TeamCreate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    if current_user.club_role not in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Insufficient permission",
        )

    team = await create_team(
        db,
        data,
        _require_club(current_user),
    )

    if current_user.club_role == ClubRole.MANAGER.value:
        db.add(
            TeamManager(
                team_id=team.id,
                user_id=current_user.id,
            )
        )
        await db.commit()

    return team


@router.get("", response_model=list[TeamResponse])
async def list_all(
    archived: bool = Query(default=False),
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    teams = await list_teams(
        db,
        _require_club(current_user),
        archived=archived,
    )

    visible_ids = await visible_team_ids(
        db,
        current_user,
    )

    if visible_ids is None:
        return teams

    return [
        team
        for team in teams
        if team.id in visible_ids
    ]




async def _manageable_team(team_id: uuid.UUID, current_user: User, db: AsyncSession):
    if current_user.club_role not in {ClubRole.DIRECTOR.value, ClubRole.MANAGER.value}:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Insufficient permission")
    team = await get_team(db, team_id)
    if not team or not await can_manage_team(db, current_user, team):
        deny_not_found("Team")
    return team

@router.post("/{team_id}/archive", response_model=TeamResponse)
async def archive(team_id: uuid.UUID, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    return await archive_team(db, await _manageable_team(team_id, current_user, db))

@router.post("/{team_id}/restore", response_model=TeamResponse)
async def restore(team_id: uuid.UUID, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    return await restore_team(db, await _manageable_team(team_id, current_user, db))

@router.delete("/{team_id}", status_code=status.HTTP_204_NO_CONTENT)
async def remove(team_id: uuid.UUID, current_user: User = Depends(require_current_user), db: AsyncSession = Depends(get_session)):
    team = await _manageable_team(team_id, current_user, db)
    logo = filename_from_logo_url(team.logo_url)
    try:
        await hard_delete_team(db, team)
    except LifecycleConflict as exc:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(exc))
    if logo:
        delete_filename(logo)
    return Response(status_code=status.HTTP_204_NO_CONTENT)

@router.post("/{team_id}/logo", response_model=TeamResponse)
async def upload_logo(
    team_id: uuid.UUID,
    logo: UploadFile = File(...),
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or not await can_manage_team(
        db,
        current_user,
        team,
    ):
        deny_not_found("Team")

    if team.archived_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Archived Teams are read-only",
        )

    previous_filename = filename_from_logo_url(team.logo_url)
    new_filename = None

    try:
        new_filename = await save_team_logo(
            team_id=team_id,
            upload=logo,
        )
    except TeamLogoTooLargeError as exc:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=str(exc),
        )
    except TeamLogoUnsupportedTypeError as exc:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=str(exc),
        )
    finally:
        await logo.close()

    logo_url = f"/api/team-logos/{new_filename}"

    try:
        updated = await set_team_logo_url(
            db,
            team_id,
            logo_url,
        )
    except Exception:
        delete_filename(new_filename)
        raise

    if not updated:
        delete_filename(new_filename)
        deny_not_found("Team")

    if (
        previous_filename
        and previous_filename != new_filename
    ):
        delete_filename(previous_filename)

    return updated


@router.get(
    "/{team_id}/players",
    response_model=list[PlayerResponse],
)
async def list_players(
    team_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or not await can_view_team(
        db,
        current_user,
        team,
    ):
        deny_not_found("Team")

    return await get_team_players(
        db,
        team_id,
    )


@router.get("/{team_id}", response_model=TeamResponse)
async def retrieve(
    team_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    team = await get_team(db, team_id)
    if not team or not await can_view_team(
        db,
        current_user,
        team,
    ):
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
    if not team or not await can_manage_team(
        db,
        current_user,
        team,
    ):
        deny_not_found("Team")

    if team.archived_at is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Archived Teams are read-only",
        )

    updated = await update_team(
        db,
        team_id,
        data,
    )

    if not updated:
        deny_not_found("Team")

    return updated
