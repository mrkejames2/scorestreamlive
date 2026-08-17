"""Add authoritative game elapsed time to scoring events.

Revision ID: 20260817_0007
Revises: 20260815_0006
Create Date: 2026-08-17

Historical scoring events remain NULL because their true match minute cannot
be reconstructed safely from wall-clock created_at alone.
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260817_0007"
down_revision: Union[str, None] = "20260815_0006"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "scoring_events",
        sa.Column("game_elapsed_seconds", sa.Integer(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("scoring_events", "game_elapsed_seconds")
