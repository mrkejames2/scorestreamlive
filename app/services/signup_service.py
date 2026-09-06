"""Provider-neutral public signup orchestration."""
from datetime import datetime,timedelta,timezone
from email.utils import parseaddr
from sqlalchemy import func,select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from app.models.signup_intent import SignupIntent
from app.models.user import User
SIGNUP_TTL_HOURS=48
ACTIVE_STATUSES=("PENDING","READY_FOR_CHECKOUT")
class SignupRejected(Exception): pass
def normalize_email(value):
    value=value.strip(); _,parsed=parseaddr(value)
    if not parsed or parsed!=value or "@" not in parsed: raise ValueError("Enter a valid email address.")
    return parsed.casefold()
def clean(value,field,max_len):
    value=" ".join(value.split())
    if not value: raise ValueError(f"{field} is required.")
    if len(value)>max_len: raise ValueError(f"{field} is too long.")
    if any(ord(c)<32 for c in value): raise ValueError(f"{field} contains invalid characters.")
    return value
async def create_or_resume_signup(db:AsyncSession,*,email,first_name,last_name,organization_name,source="public-web"):
    normalized=normalize_email(email)
    first_name=clean(first_name,"First name",100); last_name=clean(last_name,"Last name",100)
    organization_name=clean(organization_name,"Organization name",180)
    now=datetime.now(timezone.utc)
    existing=await db.scalar(select(User.id).where(func.lower(User.email)==normalized))
    if existing is not None: raise SignupRejected("We can't continue this signup using those details.")
    intents=(await db.scalars(select(SignupIntent).where(
        SignupIntent.email_normalized==normalized,SignupIntent.status.in_(ACTIVE_STATUSES)
    ).order_by(SignupIntent.created_at.desc()))).all()
    for intent in intents:
        if intent.expires_at<=now:
            intent.status="EXPIRED"; intent.updated_at=now; continue
        intent.email=email.strip(); intent.first_name=first_name; intent.last_name=last_name
        intent.organization_name=organization_name; intent.status="READY_FOR_CHECKOUT"; intent.updated_at=now
        await db.commit(); await db.refresh(intent); return intent
    intent=SignupIntent(email=email.strip(),email_normalized=normalized,first_name=first_name,last_name=last_name,
        organization_name=organization_name,status="READY_FOR_CHECKOUT",
        expires_at=now+timedelta(hours=SIGNUP_TTL_HOURS),source=source)
    db.add(intent)
    try:
        await db.commit()
    except IntegrityError:
        await db.rollback()
        raced=await db.scalar(select(SignupIntent).where(
            SignupIntent.email_normalized==normalized,
            SignupIntent.status.in_(ACTIVE_STATUSES)
        ).order_by(SignupIntent.created_at.desc()))
        if raced is None:
            raise
        raced.email=email.strip(); raced.first_name=first_name; raced.last_name=last_name
        raced.organization_name=organization_name; raced.status="READY_FOR_CHECKOUT"; raced.updated_at=now
        await db.commit(); await db.refresh(raced); return raced
    await db.refresh(intent); return intent
