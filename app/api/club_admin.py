"""Director Club user and assignment administration API."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.authorization import require_director
from app.auth.dependencies import require_current_user
from app.auth.roles import ClubRole
from app.database import get_session
from app.models.user import User
from app.services.access_admin_service import (
    AccessAdminConflict,
    AccessAdminNotFound,
    assign_game_operator,
    assign_team_manager,
    assignments,
    get_club_member,
    list_club_members,
    member_assignments,
    remove_game_operator,
    remove_team_manager,
    update_club_member,
)

router = APIRouter(prefix="/api/admin", tags=["club-admin"])


class MemberUpdate(BaseModel):
    role: ClubRole | None = None
    is_active: bool | None = None


class AssignmentCreate(BaseModel):
    user_id: uuid.UUID


def director(user: User) -> uuid.UUID:
    require_director(user)
    return user.club_id


def member(user: User, assignment_data: dict | None = None) -> dict:
    payload = {
        "id": str(user.id),
        "email": user.email,
        "display_name": user.display_name,
        "club_role": user.club_role,
        "is_active": user.is_active,
    }
    if assignment_data is not None:
        payload["assignments"] = assignment_data
    return payload


@router.get("/members")
async def members(
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    club_id = director(current_user)
    return [member(user) for user in await list_club_members(db, club_id)]


@router.get("/members/{user_id}")
async def get_member(
    user_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    club_id = director(current_user)
    try:
        user = await get_club_member(db, club_id, user_id)
        user_assignments = await member_assignments(db, club_id, user_id)
    except AccessAdminNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    return member(user, user_assignments)


@router.patch("/members/{user_id}")
async def patch_member(
    user_id: uuid.UUID,
    data: MemberUpdate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    club_id = director(current_user)

    if data.role is None and data.is_active is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="At least one of role or is_active is required",
        )

    try:
        user = await update_club_member(
            db,
            club_id,
            user_id,
            role=data.role,
            is_active=data.is_active,
        )
        user_assignments = await member_assignments(db, club_id, user_id)
    except AccessAdminNotFound as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except AccessAdminConflict as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        ) from exc

    return member(user, user_assignments)


@router.get("/assignments")
async def get_assignments(
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    return await assignments(db, director(current_user))


@router.post("/teams/{team_id}/managers", status_code=201)
async def add_manager(
    team_id: uuid.UUID,
    data: AssignmentCreate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    try:
        assignment = await assign_team_manager(
            db,
            director(current_user),
            team_id,
            data.user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {
        "id": str(assignment.id),
        "team_id": str(assignment.team_id),
        "user_id": str(assignment.user_id),
    }


@router.delete("/teams/{team_id}/managers/{user_id}", status_code=204)
async def del_manager(
    team_id: uuid.UUID,
    user_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    try:
        await remove_team_manager(
            db,
            director(current_user),
            team_id,
            user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/games/{game_id}/operators", status_code=201)
async def add_operator(
    game_id: uuid.UUID,
    data: AssignmentCreate,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    try:
        assignment = await assign_game_operator(
            db,
            director(current_user),
            game_id,
            data.user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return {
        "id": str(assignment.id),
        "game_id": str(assignment.game_id),
        "user_id": str(assignment.user_id),
    }


@router.delete("/games/{game_id}/operators/{user_id}", status_code=204)
async def del_operator(
    game_id: uuid.UUID,
    user_id: uuid.UUID,
    current_user: User = Depends(require_current_user),
    db: AsyncSession = Depends(get_session),
):
    try:
        await remove_game_operator(
            db,
            director(current_user),
            game_id,
            user_id,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
