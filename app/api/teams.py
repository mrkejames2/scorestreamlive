"""Team REST API routes."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_session
from app.schemas.player import PlayerResponse
from app.schemas.team import TeamCreate, TeamUpdate, TeamResponse
from app.services.player_service import get_team_players
from app.services.team_service import create_team, get_team, list_teams, update_team

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