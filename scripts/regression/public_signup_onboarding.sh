#!/usr/bin/env bash
set -euo pipefail
f=0; pass(){ echo "PASS $*"; }; fail(){ echo "FAIL $*"; f=1; }
for p in app/models/signup_intent.py app/services/signup_service.py app/api/public_signup.py app/web/signup.py static/signup.html static/js/signup.js alembic/versions/20260907_0018_add_signup_intents.py;do [[ -f "$p" ]]&&pass "file $p"||fail "missing $p";done
grep -Fq 'down_revision="20260907_0017"' alembic/versions/20260907_0018_add_signup_intents.py&&pass "migration extends M18-A"||fail "migration head"
grep -Fq 'READY_FOR_CHECKOUT' alembic/versions/20260907_0018_add_signup_intents.py \
  && grep -Fq 'status="READY_FOR_CHECKOUT"' app/services/signup_service.py \
  && pass "READY_FOR_CHECKOUT is schema-valid and service-driven" \
  || fail "READY_FOR_CHECKOUT lifecycle contract"
grep -Fq 'href="/signup">Get Started</a>' static/index.html&&pass "marketing CTA"||fail "marketing CTA"
grep -Fq 'prefix="/api/public/signup"' app/api/public_signup.py&&pass "public REST boundary"||fail "public REST boundary"
grep -Fq 'uq_signup_intents_active_email' app/models/signup_intent.py&&pass "active signup email concurrency guard"||fail "active signup email concurrency guard"
grep -Fq 'IntegrityError' app/services/signup_service.py&&pass "signup race resumes winning active intent"||fail "signup race handling"
if grep -Eq 'Club\(|Subscription\(|User\(' app/services/signup_service.py;then fail "signup provisions tenancy";else pass "signup creates intent only";fi
for x in stripe paddle redis kafka nats rabbitmq celery kubernetes;do grep -Eriq "$x" app/models/signup_intent.py app/services/signup_service.py app/api/public_signup.py app/web/signup.py static/signup.html static/js/signup.js&&fail "introduces $x"||pass "does not introduce $x";done
echo
echo "M18-B runtime signup contract"
sudo docker compose exec -T app python3 - <<'PY' || f=1
import asyncio, uuid
from datetime import datetime, timedelta, timezone
import json
import urllib.error
import urllib.request
from sqlalchemy import delete, func, select, update
from app.database import AsyncSessionLocal
from app.models.club import Club
from app.models.subscription import Subscription
from app.models.signup_intent import SignupIntent
from app.models.user import User

BASE_URL="http://localhost:8000"
email=f"m18b-validation-{uuid.uuid4().hex}@example.invalid"
payload={
    "email":email,
    "first_name":"M18B",
    "last_name":"Validation",
    "organization_name":"M18B Validation Organization",
}

async def counts(db):
    return (
        await db.scalar(select(func.count()).select_from(User)),
        await db.scalar(select(func.count()).select_from(Club)),
        await db.scalar(select(func.count()).select_from(Subscription)),
    )

async def main():
    async with AsyncSessionLocal() as db:
        before=await counts(db)

    def post_signup(body):
        req=urllib.request.Request(BASE_URL+"/api/public/signup",data=json.dumps(body).encode(),headers={"Content-Type":"application/json"},method="POST")
        try:
            with urllib.request.urlopen(req,timeout=10) as response:
                return response.status,json.loads(response.read().decode())
        except urllib.error.HTTPError as exc:
            return exc.code,json.loads(exc.read().decode())

    code,first=post_signup(payload)
    assert code==201,(code,first)
    assert first["status"]=="READY_FOR_CHECKOUT"
    first_id=first["signup_intent_id"]
    retry=dict(payload); retry["email"]=f"  {email.upper()}  "; retry["organization_name"]="M18B Validation Organization Updated"
    code,second=post_signup(retry)
    assert code==201,(code,second)
    assert second["signup_intent_id"]==first_id,(first,second)

    async with AsyncSessionLocal() as db:
        active=(await db.scalars(select(SignupIntent).where(
            SignupIntent.email_normalized==email.casefold(),
            SignupIntent.status.in_(("PENDING","READY_FOR_CHECKOUT"))
        ))).all()
        assert len(active)==1,len(active)
        assert await counts(db)==before

        await db.execute(update(SignupIntent).where(
            SignupIntent.id==uuid.UUID(first_id)
        ).values(expires_at=datetime.now(timezone.utc)-timedelta(minutes=1)))
        await db.commit()

    code,third=post_signup(payload)
    assert code==201,(code,third)
    assert third["signup_intent_id"]!=first_id,(first,third)

    async with AsyncSessionLocal() as db:
        old=await db.get(SignupIntent,uuid.UUID(first_id))
        assert old.status=="EXPIRED",old.status
        existing_email=await db.scalar(select(User.email).limit(1))
        before_existing=await counts(db)

    if existing_email:
        existing_payload=dict(payload)
        existing_payload["email"]=existing_email
        code,body=post_signup(existing_payload)
        assert code==409,(code,body)
        assert body.get("detail")=="We can't continue this signup using those details."
        async with AsyncSessionLocal() as db:
            assert await counts(db)==before_existing

    async with AsyncSessionLocal() as db:
        await db.execute(delete(SignupIntent).where(SignupIntent.email_normalized==email.casefold()))
        await db.commit()

    print("PASS runtime create/resume/expire/privacy/no-provisioning contract")

asyncio.run(main())
PY

sudo docker compose exec -T app python3 - <<'PY' || f=1
import app.models
from app.database import Base
assert "signup_intents" in Base.metadata.tables
print("PASS SQLAlchemy metadata registers signup_intents")
PY
[[ "$f" -eq 0 ]]
