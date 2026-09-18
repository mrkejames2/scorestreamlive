"""add game sponsor assignments"""
from alembic import op
import sqlalchemy as sa
revision="20260917_0028"; down_revision="20260917_0027"; branch_labels=None; depends_on=None
def upgrade():
    op.create_table("game_sponsors",sa.Column("game_id",sa.Uuid(),nullable=False),sa.Column("sponsor_id",sa.Uuid(),nullable=False),sa.Column("display_order",sa.Integer(),server_default="0",nullable=False),sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),sa.ForeignKeyConstraint(["game_id"],["games.id"],ondelete="CASCADE"),sa.ForeignKeyConstraint(["sponsor_id"],["sponsors.id"],ondelete="CASCADE"),sa.PrimaryKeyConstraint("game_id","sponsor_id"))
    op.create_index("ix_game_sponsors_game_id","game_sponsors",["game_id"],unique=False); op.create_index("ix_game_sponsors_sponsor_id","game_sponsors",["sponsor_id"],unique=False)
def downgrade():
    op.drop_index("ix_game_sponsors_sponsor_id",table_name="game_sponsors"); op.drop_index("ix_game_sponsors_game_id",table_name="game_sponsors"); op.drop_table("game_sponsors")
