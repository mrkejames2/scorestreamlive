#!/usr/bin/env python3
from pathlib import Path

def replace_once(path, old, new):
    p=Path(path); s=p.read_text()
    if s.count(old)!=1:
        raise SystemExit(f"{path}: expected one matching block, found {s.count(old)}")
    p.write_text(s.replace(old,new,1))

# Authorization semantics.
replace_once("app/auth/authorization.py",
'''    if user.club_role == ClubRole.DIRECTOR.value:
        return None

    if user.club_role == ClubRole.MANAGER.value:
        result = await db.execute(
            select(TeamManager.team_id)
            .join(Team, Team.id == TeamManager.team_id)
            .where(
                TeamManager.user_id == user.id,
                Team.club_id == user.club_id,
            )
        )
        return set(result.scalars().all())
''',
'''    if user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return None
''')

p=Path("app/auth/authorization.py"); s=p.read_text()
old='''    if user.club_role == ClubRole.DIRECTOR.value:
        return None

    if user.club_role == ClubRole.OPERATOR.value:
'''
if s.count(old)!=1: raise SystemExit("visible_game_ids block mismatch")
s=s.replace(old,'''    if user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return None

    if user.club_role == ClubRole.OPERATOR.value:
''',1)
old='''    if user.club_role == ClubRole.MANAGER.value:
        managed_team_ids = await visible_team_ids(db, user)
        if not managed_team_ids:
            return set()

        result = await db.execute(
            select(Game.id).where(
                Game.club_id == user.club_id,
                or_(
                    Game.home_team_id.in_(managed_team_ids),
                    Game.away_team_id.in_(managed_team_ids),
                ),
            )
        )
        return set(result.scalars().all())

'''
if s.count(old)!=1: raise SystemExit("Manager visible_game_ids block mismatch")
s=s.replace(old,"",1)
old='''    if user.club_role == ClubRole.DIRECTOR.value:
        for team_id in (home_team_id, away_team_id):
            if team_id is None:
                continue
            team = await db.get(Team, team_id)
            if not team or team.club_id != user.club_id:
                return False
        return True

    if user.club_role != ClubRole.MANAGER.value:
        return False

    managed_team_ids = await visible_team_ids(db, user)
    if managed_team_ids is None:
        return False

    for team_id in (home_team_id, away_team_id):
        if team_id is None or team_id not in managed_team_ids:
            return False

    return True
'''
new='''    if user.club_role not in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return False

    for team_id in (home_team_id, away_team_id):
        if team_id is None:
            continue
        team = await db.get(Team, team_id)
        if not team or team.club_id != user.club_id:
            return False

    return True
'''
if s.count(old)!=1: raise SystemExit("create_game_with_teams block mismatch")
s=s.replace(old,new,1)
old='''    if user.club_role == ClubRole.DIRECTOR.value:
        return True

    if user.club_role != ClubRole.MANAGER.value:
        return False

    result = await db.execute(
        select(
            exists().where(
                TeamManager.team_id == team.id,
                TeamManager.user_id == user.id,
            )
        )
    )
    return bool(result.scalar())
'''
if s.count(old)!=1: raise SystemExit("can_manage_team block mismatch")
s=s.replace(old,'''    return user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }
''',1)
old='''    if user.club_role == ClubRole.DIRECTOR.value:
        return True

    if user.club_role == ClubRole.OPERATOR.value:
'''
if s.count(old)!=1: raise SystemExit("can_operate_game role block mismatch")
s=s.replace(old,'''    if user.club_role in {
        ClubRole.DIRECTOR.value,
        ClubRole.MANAGER.value,
    }:
        return True

    if user.club_role == ClubRole.OPERATOR.value:
''',1)
old='''    if user.club_role == ClubRole.MANAGER.value:
        team_ids = [
            team_id
            for team_id in (game.home_team_id, game.away_team_id)
            if team_id is not None
        ]
        if not team_ids:
            return False

        result = await db.execute(
            select(
                exists().where(
                    TeamManager.user_id == user.id,
                    TeamManager.team_id.in_(team_ids),
                )
            )
        )
        return bool(result.scalar())

'''
if s.count(old)!=1: raise SystemExit("old Manager can_operate_game block mismatch")
s=s.replace(old,"",1)
s=s.replace("from sqlalchemy import exists, or_, select\n","from sqlalchemy import exists, select\n")
s=s.replace("from app.models.team_manager import TeamManager\n","")
p.write_text(s)

# Manager-created teams no longer need TeamManager rows.
p=Path("app/api/teams.py"); s=p.read_text().replace("from app.models.team_manager import TeamManager\n","")
old='''    team = await create_team(
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
'''
if s.count(old)!=1: raise SystemExit("teams.py Manager auto-assignment block mismatch")
p.write_text(s.replace(old,'''    return await create_team(
        db,
        data,
        _require_club(current_user),
    )
''',1))

# Sponsor library read for Manager; mutations remain Director-only.
p=Path("app/api/sponsors.py"); s=p.read_text()
anchor='''def _require_director_club(user:User)->uuid.UUID:
    if user.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if user.club_role!="DIRECTOR": raise HTTPException(status_code=403,detail="Director access required.")
    return user.club_id
'''
if s.count(anchor)!=1: raise SystemExit("sponsors.py Director helper mismatch")
s=s.replace(anchor,anchor+'''def _require_manager_club(user:User)->uuid.UUID:
    if user.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if user.club_role not in {"DIRECTOR","MANAGER"}: raise HTTPException(status_code=403,detail="Director or Manager access required.")
    return user.club_id
''',1)
old="return await list_sponsors(db,_require_director_club(current_user))"
if s.count(old)!=1: raise SystemExit("sponsors.py list route mismatch")
p.write_text(s.replace(old,"return await list_sponsors(db,_require_manager_club(current_user))",1))

# Game sponsor assignment for Director/Manager.
p=Path("app/api/game_sponsors.py"); s=p.read_text()
s=s.replace("from app.auth.dependencies import require_current_user\n","from app.auth.authorization import can_operate_game, deny_not_found\nfrom app.auth.dependencies import require_current_user\n",1)
s=s.replace("from app.models.user import User\n","from app.models.game import Game\nfrom app.models.user import User\n",1)
old='''def _director_club(u):
    if u.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if u.club_role!="DIRECTOR": raise HTTPException(status_code=403,detail="Director access required.")
    return u.club_id
'''
new='''async def _manageable_game(db,user,game_id):
    if user.club_id is None: raise HTTPException(status_code=409,detail="User is not assigned to a Club")
    if user.club_role not in {"DIRECTOR","MANAGER"}: raise HTTPException(status_code=403,detail="Director or Manager access required.")
    game=await db.get(Game,game_id)
    if not game or not await can_operate_game(db,user,game): deny_not_found("Game")
    if game.archived_at is not None: raise HTTPException(status_code=409,detail="Archived Games are read-only")
    return game
'''
if s.count(old)!=1: raise SystemExit("game_sponsors.py Director helper mismatch")
s=s.replace(old,new,1)
old='''@router.get("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def retrieve(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)): return _response(await list_game_sponsors(db,_director_club(current_user),game_id))
@router.put("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def replace(game_id:uuid.UUID,data:GameSponsorReplace,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)): return _response(await replace_game_sponsors(db,_director_club(current_user),game_id,data.sponsor_ids))
'''
new='''@router.get("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def retrieve(game_id:uuid.UUID,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    game=await _manageable_game(db,current_user,game_id)
    return _response(await list_game_sponsors(db,game.club_id,game_id))
@router.put("/{game_id}/sponsors",response_model=list[GameSponsorResponse])
async def replace(game_id:uuid.UUID,data:GameSponsorReplace,current_user:User=Depends(require_current_user),db:AsyncSession=Depends(get_session)):
    game=await _manageable_game(db,current_user,game_id)
    return _response(await replace_game_sponsors(db,game.club_id,game_id,data.sponsor_ids))
'''
if s.count(old)!=1: raise SystemExit("game_sponsors.py routes mismatch")
p.write_text(s.replace(old,new,1))
print("M19 AUTH-HF1 implementation applied.")
