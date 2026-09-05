"""Password recovery and signed-in password change services for M17-E."""
import hashlib, logging, secrets, uuid
from datetime import datetime, timedelta, timezone
from urllib.parse import urlencode
from sqlalchemy import delete, select
from sqlalchemy.ext.asyncio import AsyncSession
from app.auth.password_policy import validate_password
from app.config import settings
from app.models.user import User
from app.models.user_password_reset import UserPasswordReset
from app.models.user_session import UserSession
from app.services.auth_service import get_user_by_email, hash_password, hash_session_token, normalize_email, verify_password
from app.services.email_service import EmailDeliveryError, send_password_reset_email

logger=logging.getLogger("app")
class PasswordResetInvalid(ValueError): pass
class PasswordChangeInvalid(ValueError): pass
def now(): return datetime.now(timezone.utc)
def hash_password_reset_token(token): return hashlib.sha256(token.encode("utf-8")).hexdigest()
def reset_status(r):
    if r.used_at:return "USED"
    if r.revoked_at:return "REVOKED"
    e=r.expires_at if r.expires_at.tzinfo else r.expires_at.replace(tzinfo=timezone.utc)
    return "EXPIRED" if e<=now() else "PENDING"
def reset_url(token):
    return f"{settings.PUBLIC_BASE_URL.rstrip('/')}/reset-password?{urlencode({'token':token})}"

async def revoke_outstanding_password_resets(db,user_id,*,commit=True):
    q=await db.execute(select(UserPasswordReset).where(UserPasswordReset.user_id==user_id,UserPasswordReset.used_at.is_(None),UserPasswordReset.revoked_at.is_(None)))
    rows=list(q.scalars().all()); ts=now()
    for r in rows:r.revoked_at=ts
    if commit: await db.commit()
    return len(rows)

async def request_password_reset(db,email):
    user=await get_user_by_email(db,normalize_email(email))
    if not user or not user.is_active:return None
    q=await db.execute(select(UserPasswordReset).where(UserPasswordReset.user_id==user.id).order_by(UserPasswordReset.created_at.desc()))
    pending=[r for r in q.scalars().all() if reset_status(r)=="PENDING"]; ts=now()
    if pending:
        c=pending[0].created_at if pending[0].created_at.tzinfo else pending[0].created_at.replace(tzinfo=timezone.utc)
        if (ts-c).total_seconds()<settings.PASSWORD_RESET_RESEND_SECONDS:return None
    for r in pending:r.revoked_at=ts
    raw=secrets.token_urlsafe(48)
    r=UserPasswordReset(id=uuid.uuid4(),user_id=user.id,token_hash=hash_password_reset_token(raw),
        expires_at=ts+timedelta(minutes=settings.PASSWORD_RESET_TTL_MINUTES),created_at=ts)
    db.add(r); await db.commit(); await db.refresh(r)
    url=reset_url(raw)
    try:
        await send_password_reset_email(email=user.email,display_name=user.display_name,reset_url=url,expires_at=r.expires_at)
    except EmailDeliveryError:
        r.revoked_at=now(); await db.commit()
        logger.exception("Password reset delivery failed",extra={"event":"password_reset.email.failed","user_id":str(user.id)})
        return None
    return url if settings.APP_ENV!="production" and settings.EMAIL_DELIVERY_MODE=="log" else None

async def resolve_password_reset(db,raw_token,*,for_update=False):
    if not raw_token: raise PasswordResetInvalid("Password reset link is invalid or expired")
    q=select(UserPasswordReset).where(UserPasswordReset.token_hash==hash_password_reset_token(raw_token))
    if for_update:q=q.with_for_update()
    res=await db.execute(q); r=res.scalar_one_or_none()
    if not r or reset_status(r)!="PENDING":raise PasswordResetInvalid("Password reset link is invalid or expired")
    user=await db.get(User,r.user_id)
    if not user or not user.is_active:raise PasswordResetInvalid("Password reset link is invalid or expired")
    return r

async def consume_password_reset(db,*,raw_token,password):
    validate_password(password); r=await resolve_password_reset(db,raw_token,for_update=True)
    user=await db.get(User,r.user_id)
    if not user or not user.is_active:
        await db.rollback(); raise PasswordResetInvalid("Password reset link is invalid or expired")
    ts=now(); user.password_hash=hash_password(password); user.updated_at=ts; r.used_at=ts
    await db.execute(delete(UserSession).where(UserSession.user_id==user.id))
    await db.commit(); await db.refresh(user); return user

async def change_password(db,*,user,current_password,new_password,current_session_token):
    if not verify_password(user.password_hash,current_password):raise PasswordChangeInvalid("Current password is incorrect")
    validate_password(new_password); user.password_hash=hash_password(new_password); user.updated_at=now()
    if current_session_token:
        h=hash_session_token(current_session_token)
        await db.execute(delete(UserSession).where(UserSession.user_id==user.id,UserSession.token_hash!=h))
    else:
        await db.execute(delete(UserSession).where(UserSession.user_id==user.id))
    await revoke_outstanding_password_resets(db,user.id,commit=False)
    await db.commit()
