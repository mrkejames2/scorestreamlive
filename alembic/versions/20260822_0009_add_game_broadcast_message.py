"""add game broadcast message

Revision ID: 20260822_0009
Revises: 20260818_0008
"""

from alembic import op
import sqlalchemy as sa

revision = "20260822_0009"
down_revision = "20260818_0008"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "games",
        sa.Column("broadcast_message", sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("games", "broadcast_message")
