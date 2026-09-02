"""add scoring command request id for idempotency

Revision ID: 20260902_0013
Revises: 20260824_0012
"""

from alembic import op
import sqlalchemy as sa

revision = "20260902_0013"
down_revision = "20260824_0012"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Nullable preserves every historical scoring event. New M16-A clients
    # supply a request_id; legacy rows/callers remain valid during rollout.
    op.add_column(
        "scoring_events",
        sa.Column("request_id", sa.Uuid(), nullable=True),
    )
    op.create_index(
        "ux_scoring_events_request_id",
        "scoring_events",
        ["request_id"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index(
        "ux_scoring_events_request_id",
        table_name="scoring_events",
    )
    op.drop_column("scoring_events", "request_id")
