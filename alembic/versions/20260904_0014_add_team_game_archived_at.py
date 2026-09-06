"""add Team and Game archive timestamps

Revision ID: 20260904_0014
Revises: 20260902_0013
"""

from alembic import op
import sqlalchemy as sa

revision = "20260904_0014"
down_revision = "20260902_0013"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("teams", sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("games", sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_teams_club_archived_at", "teams", ["club_id", "archived_at"], unique=False)
    op.create_index("ix_games_club_archived_at", "games", ["club_id", "archived_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_games_club_archived_at", table_name="games")
    op.drop_index("ix_teams_club_archived_at", table_name="teams")
    op.drop_column("games", "archived_at")
    op.drop_column("teams", "archived_at")
