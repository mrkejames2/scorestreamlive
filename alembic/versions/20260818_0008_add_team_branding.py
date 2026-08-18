"""Add Team branding metadata.

Revision ID: 20260818_0008
Revises: 20260817_0007
Create Date: 2026-08-18
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "20260818_0008"
down_revision: Union[str, None] = "20260817_0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "teams",
        sa.Column("logo_url", sa.String(length=500), nullable=True),
    )
    op.add_column(
        "teams",
        sa.Column("primary_color", sa.String(length=7), nullable=True),
    )
    op.add_column(
        "teams",
        sa.Column("secondary_color", sa.String(length=7), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("teams", "secondary_color")
    op.drop_column("teams", "primary_color")
    op.drop_column("teams", "logo_url")
