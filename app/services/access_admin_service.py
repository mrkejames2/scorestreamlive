"""Director member and assignment services."""
import uuid
from datetime import datetime,timezone
from sqlalchemy import delete,select
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.roles import ClubRole
from app.models.game import Game
from app.models.game_operator import GameOperator
from app.models.team import Team
from app.models.team_manager import TeamManager
from app.models.user import User
from app.services.auth_service import get_user_by_email,hash_password,normalize_email

async def list_club_members(db,club_id):
    r=await db.execute(select(User).where(User.club_id==club_id).order_by(User.display_name.asc().nulls_last(),User.email.asc()))
    return list(r.scalars().all())

async def create_club_member(db,club_id,email,display_name,role,password):
    email=normalize_email(email)
    if not email or "@" not in email: raise ValueError("Valid email is required")
    if len(password)<8: raise ValueError("Temporary password must be at least 8 characters")
    if role not in {ClubRole.MANAGER,ClubRole.OPERATOR}: raise ValueError("New members must be Manager or Operator")
    if await get_user_by_email(db,email): raise ValueError("A user with that email already exists")
    now=datetime.now(timezone.utc)
    u=User(email=email,display_name=(display_name or "").strip() or None,password_hash=hash_password(password),is_active=True,club_id=club_id,club_role=role.value,created_at=now,updated_at=now)
    db.add(u);await db.commit();await db.refresh(u);return u

async def assign_team_manager(db,club_id,team_id,user_id):
    t=await db.get(Team,team_id);u=await db.get(User,user_id)
    if not t or t.club_id!=club_id: raise ValueError("Team not found")
    if not u or u.club_id!=club_id or u.club_role!=ClubRole.MANAGER.value: raise ValueError("Manager not found")
    r=await db.execute(select(TeamManager).where(TeamManager.team_id==team_id,TeamManager.user_id==user_id));a=r.scalar_one_or_none()
    if a:return a
    a=TeamManager(team_id=team_id,user_id=user_id);db.add(a);await db.commit();await db.refresh(a);return a

async def assign_game_operator(db,club_id,game_id,user_id):
    g=await db.get(Game,game_id);u=await db.get(User,user_id)
    if not g or g.club_id!=club_id: raise ValueError("Game not found")
    if not u or u.club_id!=club_id or u.club_role!=ClubRole.OPERATOR.value: raise ValueError("Operator not found")
    r=await db.execute(select(GameOperator).where(GameOperator.game_id==game_id,GameOperator.user_id==user_id));a=r.scalar_one_or_none()
    if a:return a
    a=GameOperator(game_id=game_id,user_id=user_id);db.add(a);await db.commit();await db.refresh(a);return a

async def remove_team_manager(db,club_id,team_id,user_id):
    t=await db.get(Team,team_id)
    if not t or t.club_id!=club_id: raise ValueError("Team not found")
    await db.execute(delete(TeamManager).where(TeamManager.team_id==team_id,TeamManager.user_id==user_id));await db.commit()

async def remove_game_operator(db,club_id,game_id,user_id):
    g=await db.get(Game,game_id)
    if not g or g.club_id!=club_id: raise ValueError("Game not found")
    await db.execute(delete(GameOperator).where(GameOperator.game_id==game_id,GameOperator.user_id==user_id));await db.commit()

async def assignments(db,club_id):
    tm=await db.execute(select(TeamManager,Team,User).join(Team,Team.id==TeamManager.team_id).join(User,User.id==TeamManager.user_id).where(Team.club_id==club_id,User.club_id==club_id))
    go=await db.execute(select(GameOperator,Game,User).join(Game,Game.id==GameOperator.game_id).join(User,User.id==GameOperator.user_id).where(Game.club_id==club_id,User.club_id==club_id))
    return {"team_managers":[{"team_id":str(t.id),"team_name":t.name,"user_id":str(u.id),"user_name":u.display_name or u.email} for _,t,u in tm.all()],
            "game_operators":[{"game_id":str(g.id),"game_name":g.name,"user_id":str(u.id),"user_name":u.display_name or u.email} for _,g,u in go.all()]}
