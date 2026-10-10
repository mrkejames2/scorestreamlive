"""M19-HF11 live event lower-third announcements."""
import sqlalchemy as sa
from alembic import op

revision = "20261010_0038"
down_revision = "20261004_0037"
branch_labels = None
depends_on = None

def upgrade():
    op.create_table("game_announcements",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("game_id", sa.Uuid(), sa.ForeignKey("games.id", ondelete="CASCADE"), nullable=False),
        sa.Column("position", sa.Integer(), nullable=False),
        sa.Column("number", sa.String(20), nullable=False, server_default=""),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("subtitle", sa.String(160), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False))
    op.create_index("ix_game_announcements_game_id", "game_announcements", ["game_id"])
    op.create_table("game_announcement_states",
        sa.Column("game_id", sa.Uuid(), sa.ForeignKey("games.id", ondelete="CASCADE"), primary_key=True),
        sa.Column("title", sa.String(100), nullable=False, server_default="SENIOR NIGHT"),
        sa.Column("active_id", sa.Uuid(), sa.ForeignKey("game_announcements.id", ondelete="SET NULL")),
        sa.Column("visible", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("version", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False))

def downgrade():
    op.drop_table("game_announcement_states")
    op.drop_index("ix_game_announcements_game_id", table_name="game_announcements")
    op.drop_table("game_announcements")
