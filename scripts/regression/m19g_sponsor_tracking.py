#!/usr/bin/env python3
from pathlib import Path
required=["app/models/sponsor_impression.py","app/models/game_sponsor_tracking_state.py","app/services/sponsor_impression_service.py","app/api/sponsor_reports.py","alembic/versions/20260920_0030_add_sponsor_impression_tracking.py","static/js/games/sponsor-report-m19g.js","static/css/sponsor-report-m19g.css"]
missing=[p for p in required if not Path(p).exists()];assert not missing,f"missing M19-G files: {missing}"
s=Path("app/services/sponsor_impression_service.py").read_text()
for token in ["TRACKED_PHASES","first_half","second_half","reconcile_sponsor_tracking","sponsor_report"]:assert token in s,token
print("PASS: M19-G sponsor tracking regression")

# Historical sponsor integrity regression guards.
model=Path("app/models/sponsor_impression.py").read_text()
migration=Path("alembic/versions/20260920_0030_add_sponsor_impression_tracking.py").read_text()

assert "sponsor_name:Mapped[str]" in model, "SponsorImpression must snapshot sponsor_name"
assert 'ForeignKey("sponsors.id",ondelete="SET NULL")' in model, "sponsor impression FK must use SET NULL"
assert "nullable=True,index=True" in model, "historical sponsor_id must be nullable"

assert 'sa.Column("sponsor_name",sa.String(255),nullable=False)' in migration, "0030 must create sponsor_name snapshot"
assert 'sa.Column("sponsor_id",sa.Uuid(),nullable=True)' in migration, "0030 sponsor_id must be nullable"
assert 'sa.ForeignKeyConstraint(["sponsor_id"],["sponsors.id"],ondelete="SET NULL")' in migration, "0030 sponsor FK must use SET NULL"

assert "sponsor_name=sponsor.name" in s, "new impressions must snapshot sponsor name"
assert "key=(row.sponsor_id,row.sponsor_name)" in s, "reports must aggregate historical sponsor identity"
assert '"name":k[1]' in s, "reports must use historical sponsor_name"
assert '"sponsor_id":str(k[0]) if k[0] is not None else None' in s, "reports must support deleted sponsors"
assert "names.get(" not in s, "reports must not resolve historical names from live sponsor records"

print("PASS: M19-G historical sponsor integrity regression")
