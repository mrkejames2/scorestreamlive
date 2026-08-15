"""Add game_clocks table.

Revision ID: 20260814_0005
Revises: 20260813_0004
Create Date: 2026-08-14 21:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260814_0005"
down_revision: Union[str, None] = "20260813_0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "game_clocks",
        sa.Column("id", sa.UUID(), nullable=False),
        sa.Column("game_id", sa.UUID(), nullable=False),
        sa.Column("mode", sa.String(length=20), nullable=False),
        sa.Column(
            "status",
            sa.String(length=20),
            nullable=False,
            server_default="stopped",
        ),
        sa.Column("duration_seconds", sa.Integer(), nullable=False),
        sa.Column(
            "elapsed_seconds",
            sa.Integer(),
            nullable=False,
            server_default="0",
        ),
        sa.Column(
            "running_since",
            sa.DateTime(timezone=True),
            nullable=True,
        ),
        sa.Column(
            "version",
            sa.Integer(),
            nullable=False,
            server_default="1",
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
        ),
        sa.CheckConstraint(
            "mode IN ('count_up', 'count_down')",
            name="ck_game_clocks_mode",
        ),
        sa.CheckConstraint(
            "status IN ('stopped', 'running', 'paused')",
            name="ck_game_clocks_status",
        ),
        sa.CheckConstraint(
            "duration_seconds > 0",
            name="ck_game_clocks_duration_positive",
        ),
        sa.CheckConstraint(
            "elapsed_seconds >= 0",
            name="ck_game_clocks_elapsed_nonnegative",
        ),
        sa.CheckConstraint(
            "version >= 1",
            name="ck_game_clocks_version_positive",
        ),
        sa.ForeignKeyConstraint(
            ["game_id"],
            ["games.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "game_id",
            name="uq_game_clocks_game_id",
        ),
    )


def downgrade() -> None:
    op.drop_table("game_clocks")
