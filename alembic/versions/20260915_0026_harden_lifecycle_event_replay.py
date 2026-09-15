"""harden lifecycle event replay

Revision ID: 20260915_0026
Revises: 20260915_0025
"""
from alembic import op
import sqlalchemy as sa

revision = "20260915_0026"
down_revision = "20260915_0025"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column(
        "billing_events",
        sa.Column("subscription_external_id", sa.String(length=255), nullable=True),
    )
    op.create_index(
        "ix_billing_events_subscription_external_id",
        "billing_events",
        ["subscription_external_id"],
        unique=False,
    )


def downgrade():
    op.drop_index("ix_billing_events_subscription_external_id", table_name="billing_events")
    op.drop_column("billing_events", "subscription_external_id")
