"""M19 hotfix: add per-game Advertisement broadcast scene."""
from alembic import op
import sqlalchemy as sa
revision="20260922_0033"; down_revision="20260921_0032"; branch_labels=None; depends_on=None
CONSTRAINT="ck_game_broadcast_presentations_scene"
def upgrade():
 op.add_column("games",sa.Column("advertisement_image_url",sa.String(500),nullable=True))
 op.add_column("games",sa.Column("advertisement_enabled",sa.Boolean(),nullable=False,server_default=sa.false()))
 op.add_column("games",sa.Column("advertisement_updated_at",sa.DateTime(timezone=True),nullable=True))
 op.drop_constraint(CONSTRAINT,"game_broadcast_presentations",type_="check")
 op.create_check_constraint(CONSTRAINT,"game_broadcast_presentations","scene IN ('intro','live','advertisement','summary','thank_you')")
def downgrade():
 op.execute("UPDATE game_broadcast_presentations SET scene='live' WHERE scene='advertisement'")
 op.drop_constraint(CONSTRAINT,"game_broadcast_presentations",type_="check")
 op.create_check_constraint(CONSTRAINT,"game_broadcast_presentations","scene IN ('intro','live','summary','thank_you')")
 op.drop_column("games","advertisement_updated_at");op.drop_column("games","advertisement_enabled");op.drop_column("games","advertisement_image_url")
