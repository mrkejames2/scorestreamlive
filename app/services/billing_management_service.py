import logging
from urllib.parse import urlparse
from sqlalchemy import select
from app.billing.provider import BillingPortalRequest
from app.config import settings
from app.models.billing_external_reference import BillingExternalReference
logger=logging.getLogger("app")
class BillingManagementRejected(Exception):
 def __init__(self,message,status_code=409): super().__init__(message); self.status_code=status_code
def portal_return_url():
 base=settings.PUBLIC_BASE_URL.strip().rstrip("/"); p=urlparse(base)
 if p.scheme not in {"http","https"} or not p.netloc: raise BillingManagementRejected("Billing management is temporarily unavailable.",503)
 return base+"/account/billing"
async def create_billing_portal(db,*,current_user,provider):
 if current_user.club_role!="DIRECTOR" or current_user.club_id is None: raise BillingManagementRejected("Director access required.",403)
 refs=(await db.scalars(select(BillingExternalReference).where(BillingExternalReference.club_id==current_user.club_id,BillingExternalReference.provider==settings.BILLING_PROVIDER.strip().lower(),BillingExternalReference.resource_type=="customer"))).all()
 if not refs: raise BillingManagementRejected("Billing account is not yet available.",409)
 if len(refs)!=1: raise BillingManagementRejected("Billing account requires support.",409)
 logger.info("Billing portal requested",extra={"event":"billing.portal.requested"})
 try: result=await provider.create_billing_portal(BillingPortalRequest(refs[0].external_id,portal_return_url()))
 except Exception as exc:
  logger.warning("Billing portal provider failed",extra={"event":"billing.portal.provider_failed"})
  raise BillingManagementRejected("Billing management is temporarily unavailable.",503) from exc
 p=urlparse(result.portal_url)
 if p.scheme!="https" or not p.hostname: raise BillingManagementRejected("Invalid billing destination.",503)
 logger.info("Billing portal created",extra={"event":"billing.portal.created"}); return result
