"""add game sponsor presentation state"""
from alembic import op
import sqlalchemy as sa
revision="20260918_0029"; down_revision="20260917_0028"; branch_labels=None; depends_on=None
def upgrade():
    op.create_table("game_sponsor_presentations",sa.Column("game_id",sa.Uuid(),nullable=False),sa.Column("current_sponsor_id",sa.Uuid(),nullable=True),sa.Column("visible",sa.Boolean(),server_default=sa.true(),nullable=False),sa.Column("rotation_enabled",sa.Boolean(),server_default=sa.true(),nullable=False),sa.Column("rotation_interval_seconds",sa.Integer(),server_default="10",nullable=False),sa.Column("version",sa.Integer(),server_default="1",nullable=False),sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),sa.CheckConstraint("rotation_interval_seconds IN (5,10,15,20,30,45,60)",name="ck_game_sponsor_presentations_interval"),sa.ForeignKeyConstraint(["game_id"],["games.id"],ondelete="CASCADE"),sa.ForeignKeyConstraint(["current_sponsor_id"],["sponsors.id"],ondelete="SET NULL"),sa.PrimaryKeyConstraint("game_id"))
    op.create_index("ix_game_sponsor_presentations_current_sponsor_id","game_sponsor_presentations",["current_sponsor_id"],unique=False)
def downgrade():
    op.drop_index("ix_game_sponsor_presentations_current_sponsor_id",table_name="game_sponsor_presentations"); op.drop_table("game_sponsor_presentations")
