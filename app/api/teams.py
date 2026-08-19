"""Team REST API routes."""

import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
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


@router.post("", response_model=TeamResponse, status_code=status.HTTP_201_CREATED)
async def create(
    data: TeamCreate,
    db: AsyncSession = Depends(get_session),
):
    """Create a new Team."""
    return await create_team(db, data)


@router.get("", response_model=list[TeamResponse])
async def list_all(
    db: AsyncSession = Depends(get_session),
):
    """List all Teams."""
    return await list_teams(db)


@router.post("/{team_id}/logo", response_model=TeamResponse)
async def upload_logo(
    team_id: uuid.UUID,
    logo: UploadFile = File(...),
    db: AsyncSession = Depends(get_session),
):
    """Upload or replace a Team logo."""
    team = await get_team(db, team_id)

    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found",
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found",
        )

    if previous_filename and previous_filename != new_filename:
        delete_filename(previous_filename)

    return updated


@router.get("/{team_id}/players", response_model=list[PlayerResponse])
async def list_players(
    team_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    """Retrieve the roster (all Players) for a Team."""
    team = await get_team(db, team_id)
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found",
        )
    return await get_team_players(db, team_id)


@router.get("/{team_id}", response_model=TeamResponse)
async def retrieve(
    team_id: uuid.UUID,
    db: AsyncSession = Depends(get_session),
):
    """Retrieve a single Team by ID."""
    team = await get_team(db, team_id)
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found",
        )
    return team


@router.patch("/{team_id}", response_model=TeamResponse)
async def update(
    team_id: uuid.UUID,
    data: TeamUpdate,
    db: AsyncSession = Depends(get_session),
):
    """Update an existing Team."""
    team = await update_team(db, team_id, data)
    if not team:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Team not found",
        )
    return team
