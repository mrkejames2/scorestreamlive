import hashlib,secrets,uuid
from datetime import datetime,timedelta,timezone
from urllib.parse import urlencode
from sqlalchemy import select
from app.auth.password_policy import validate_password
from app.auth.roles import ClubRole
from app.config import settings
from app.models.club import Club
from app.models.user import User
from app.models.user_invitation import UserInvitation
from app.services.auth_service import get_user_by_email,hash_password,normalize_email
from app.services.email_service import EmailDeliveryError,send_invitation_email
class InvitationNotFound(ValueError): pass
class InvitationConflict(ValueError): pass
class InvitationInvalid(ValueError): pass
def now(): return datetime.now(timezone.utc)
def hash_invitation_token(token): return hashlib.sha256(token.encode()).hexdigest()
def status_of(i):
    if i.accepted_at:return "ACCEPTED"
    if i.revoked_at:return "REVOKED"
    e=i.expires_at if i.expires_at.tzinfo else i.expires_at.replace(tzinfo=timezone.utc)
    return "EXPIRED" if e<=now() else "PENDING"
def payload(i): return {"id":str(i.id),"email":i.email,"display_name":i.display_name,"club_role":i.club_role,"status":status_of(i),"expires_at":i.expires_at,"accepted_at":i.accepted_at,"revoked_at":i.revoked_at,"created_at":i.created_at}
def activation_url(t): return f"{settings.PUBLIC_BASE_URL.rstrip('/')}/activate?{urlencode({'token':t})}"
async def list_club_invitations(db,club_id):
    r=await db.execute(select(UserInvitation).where(UserInvitation.club_id==club_id).order_by(UserInvitation.created_at.desc())); return list(r.scalars().all())
async def get_club_invitation(db,club_id,invitation_id):
    r=await db.execute(select(UserInvitation).where(UserInvitation.id==invitation_id,UserInvitation.club_id==club_id)); i=r.scalar_one_or_none()
    if not i: raise InvitationNotFound("Invitation not found")
    return i
async def pending_for_email(db,email):
    r=await db.execute(select(UserInvitation).where(UserInvitation.email==email)); return [i for i in r.scalars().all() if status_of(i)=="PENDING"]
async def deliver(db,i,raw,inviter):
    club=await db.get(Club,i.club_id)
    if not club: raise InvitationNotFound("Club not found")
    url=activation_url(raw)
    try: await send_invitation_email(email=i.email,display_name=i.display_name,club_name=club.name,inviter_name=inviter.display_name or inviter.email,activation_url=url,expires_at=i.expires_at)
    except EmailDeliveryError:
        i.revoked_at=now();i.updated_at=now();await db.commit();raise
    return url if settings.APP_ENV!="production" and settings.EMAIL_DELIVERY_MODE=="log" else None
async def create_invitation(db,*,inviter,email,display_name,role):
    if not inviter.club_id: raise InvitationNotFound("Club not found")
    email=normalize_email(email)
    if not email or "@" not in email: raise ValueError("Valid email is required")
    if role not in {ClubRole.MANAGER,ClubRole.OPERATOR}: raise ValueError("Invitations may be sent only for Manager or Operator")
    if await get_user_by_email(db,email): raise InvitationConflict("A ScoreStreamLive account already exists for this email")
    old=await pending_for_email(db,email)
    if any(x.club_id!=inviter.club_id for x in old): raise InvitationConflict("This email already has a pending ScoreStreamLive invitation")
    ts=now()
    for x in old:x.revoked_at=ts;x.updated_at=ts
    raw=secrets.token_urlsafe(48);i=UserInvitation(id=uuid.uuid4(),club_id=inviter.club_id,email=email,display_name=(display_name or "").strip() or None,club_role=role.value,token_hash=hash_invitation_token(raw),created_by_user_id=inviter.id,expires_at=ts+timedelta(hours=settings.INVITATION_TTL_HOURS),created_at=ts,updated_at=ts)
    db.add(i);await db.commit();await db.refresh(i);return i,await deliver(db,i,raw,inviter)
async def resend_invitation(db,*,inviter,invitation_id):
    i=await get_club_invitation(db,inviter.club_id,invitation_id)
    if status_of(i)!="PENDING": raise InvitationConflict("Only a pending invitation can be resent")
    i.revoked_at=now();i.updated_at=now();await db.commit();return await create_invitation(db,inviter=inviter,email=i.email,display_name=i.display_name,role=ClubRole(i.club_role))
async def revoke_invitation(db,*,club_id,invitation_id):
    i=await get_club_invitation(db,club_id,invitation_id)
    if status_of(i)!="PENDING": raise InvitationConflict("Only a pending invitation can be revoked")
    i.revoked_at=now();i.updated_at=now();await db.commit()
async def resolve_public_invitation(db,raw_token,*,for_update=False):
    if not raw_token: raise InvitationInvalid("Invitation is invalid or expired")
    q=select(UserInvitation).where(UserInvitation.token_hash==hash_invitation_token(raw_token));q=q.with_for_update() if for_update else q
    r=await db.execute(q);i=r.scalar_one_or_none()
    if not i or status_of(i)!="PENDING": raise InvitationInvalid("Invitation is invalid or expired")
    return i
async def activation_context(db,raw):
    i=await resolve_public_invitation(db,raw);club=await db.get(Club,i.club_id)
    if not club: raise InvitationInvalid("Invitation is invalid or expired")
    return i,club
async def activate_invitation(db,*,raw_token,password,display_name):
    validate_password(password);i=await resolve_public_invitation(db,raw_token,for_update=True)
    if await get_user_by_email(db,i.email): await db.rollback();raise InvitationInvalid("Invitation is invalid or expired")
    ts=now();u=User(id=uuid.uuid4(),email=i.email,display_name=(display_name or i.display_name or "").strip() or None,password_hash=hash_password(password),is_active=True,club_id=i.club_id,club_role=i.club_role,created_at=ts,updated_at=ts);db.add(u);i.accepted_at=ts;i.updated_at=ts
    try: await db.commit()
    except Exception: await db.rollback();raise
    await db.refresh(u);return u
