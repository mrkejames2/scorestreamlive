"""Add game_lifecycles table.

Revision ID: 20260815_0006
Revises: 20260814_0005
Create Date: 2026-08-15 20:00:00.000000+00:00

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260815_0006"
down_revision: Union[str, None] = "20260814_0005"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "game_lifecycles",
        sa.Column(
            "id",
            sa.UUID(),
            nullable=False,
        ),
        sa.Column(
            "game_id",
            sa.UUID(),
            nullable=False,
        ),
        sa.Column(
            "phase",
            sa.String(length=20),
            nullable=False,
            server_default="pregame",
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
            "phase IN ("
            "'pregame', "
            "'first_half', "
            "'halftime', "
            "'second_half', "
            "'full_time'"
            ")",
            name="ck_game_lifecycles_phase",
        ),
        sa.CheckConstraint(
            "version >= 1",
            name="ck_game_lifecycles_version_positive",
        ),
        sa.ForeignKeyConstraint(
            ["game_id"],
            ["games.id"],
            ondelete="RESTRICT",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "game_id",
            name="uq_game_lifecycles_game_id",
        ),
    )


def downgrade() -> None:
    op.drop_table("game_lifecycles")
