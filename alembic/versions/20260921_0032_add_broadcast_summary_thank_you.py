"""M19 HF1B broadcast summary and thank-you scenes."""
from alembic import op
import sqlalchemy as sa
revision="20260921_0032"; down_revision="20260920_0031"; branch_labels=None; depends_on=None
CONSTRAINT="ck_game_broadcast_presentations_scene"
def upgrade():
    op.add_column("games",sa.Column("thank_you_image_url",sa.String(500),nullable=True))
    op.add_column("games",sa.Column("thank_you_enabled",sa.Boolean(),nullable=False,server_default=sa.false()))
    op.add_column("games",sa.Column("thank_you_updated_at",sa.DateTime(timezone=True),nullable=True))
    op.drop_constraint(CONSTRAINT,"game_broadcast_presentations",type_="check")
    op.create_check_constraint(CONSTRAINT,"game_broadcast_presentations","scene IN ('intro','live','summary','thank_you')")
def downgrade():
    op.execute("UPDATE game_broadcast_presentations SET scene='live' WHERE scene IN ('summary','thank_you')")
    op.drop_constraint(CONSTRAINT,"game_broadcast_presentations",type_="check")
    op.create_check_constraint(CONSTRAINT,"game_broadcast_presentations","scene IN ('intro','live')")
    op.drop_column("games","thank_you_updated_at"); op.drop_column("games","thank_you_enabled"); op.drop_column("games","thank_you_image_url")
