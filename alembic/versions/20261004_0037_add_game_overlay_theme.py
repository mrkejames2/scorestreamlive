"""M19 HF9 per-game overlay theme selection."""
from alembic import op
import sqlalchemy as sa
revision="20261004_0037"; down_revision="20261001_0036"; branch_labels=None; depends_on=None
def upgrade():
    op.add_column("games",sa.Column("overlay_theme",sa.String(32),nullable=False,server_default="standard"))
    op.create_check_constraint("ck_games_overlay_theme","games","overlay_theme IN ('standard', 'pink_out')")
def downgrade():
    op.drop_constraint("ck_games_overlay_theme","games",type_="check")
    op.drop_column("games","overlay_theme")
