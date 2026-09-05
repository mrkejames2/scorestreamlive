import asyncio, logging, smtplib
from email.message import EmailMessage
from app.config import settings
logger=logging.getLogger("app")
class EmailDeliveryError(RuntimeError): pass

def _send(msg):
    try:
        with smtplib.SMTP(settings.SMTP_HOST,settings.SMTP_PORT,timeout=20) as client:
            if settings.SMTP_USE_TLS: client.starttls()
            if settings.SMTP_USERNAME: client.login(settings.SMTP_USERNAME,settings.SMTP_PASSWORD)
            client.send_message(msg)
    except Exception as exc: raise EmailDeliveryError("Invitation email delivery failed") from exc

async def send_invitation_email(*,email,display_name,club_name,inviter_name,activation_url,expires_at):
    body=f"{display_name or 'Hello'},\n\n{inviter_name} has invited you to join {club_name} in ScoreStreamLive.\n\nActivate your account:\n{activation_url}\n\nThis invitation expires at {expires_at.isoformat()}.\n"
    if settings.EMAIL_DELIVERY_MODE=="log":
        logger.info("Invitation email (development log delivery) — to=%s activation_url=%s",email,activation_url,extra={"event":"invitation.email.logged"}); return
    if settings.EMAIL_DELIVERY_MODE!="smtp": raise EmailDeliveryError("Email delivery is not configured")
    msg=EmailMessage(); msg["Subject"]="You've been invited to ScoreStreamLive"; msg["From"]=f"{settings.EMAIL_FROM_NAME} <{settings.EMAIL_FROM_ADDRESS}>"; msg["To"]=email; msg.set_content(body)
    await asyncio.to_thread(_send,msg)
