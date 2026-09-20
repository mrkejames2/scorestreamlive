"""M19-H game stream intro and broadcast presentation."""
from alembic import op
import sqlalchemy as sa
revision="20260920_0031"; down_revision="20260920_0030"; branch_labels=None; depends_on=None
def upgrade():
    op.add_column("games",sa.Column("intro_image_url",sa.String(500),nullable=True))
    op.add_column("games",sa.Column("intro_enabled",sa.Boolean(),nullable=False,server_default=sa.false()))
    op.add_column("games",sa.Column("intro_updated_at",sa.DateTime(timezone=True),nullable=True))
    op.create_table("game_broadcast_presentations",
      sa.Column("game_id",sa.Uuid(),sa.ForeignKey("games.id",ondelete="CASCADE"),primary_key=True),
      sa.Column("scene",sa.String(20),nullable=False,server_default="live"),sa.Column("version",sa.Integer(),nullable=False,server_default="1"),
      sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),
      sa.CheckConstraint("scene IN ('intro','live')",name="ck_game_broadcast_presentations_scene"))
def downgrade():
    op.drop_table("game_broadcast_presentations"); op.drop_column("games","intro_updated_at"); op.drop_column("games","intro_enabled"); op.drop_column("games","intro_image_url")
