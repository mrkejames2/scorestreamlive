"""Harden verified billing-event recovery for M18-D.

Revision ID: 20260907_0022
Revises: 20260907_0021
"""
from alembic import op
import sqlalchemy as sa

revision = "20260907_0022"
down_revision = "20260907_0021"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("billing_events", sa.Column("object_external_id", sa.String(length=255), nullable=True))
    op.add_column("billing_events", sa.Column("provider_created_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_billing_events_processing_status", "billing_events", ["processing_status"], unique=False)
    op.create_index("ix_billing_events_object", "billing_events", ["provider", "object_external_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_billing_events_object", table_name="billing_events")
    op.drop_index("ix_billing_events_processing_status", table_name="billing_events")
    op.drop_column("billing_events", "provider_created_at")
    op.drop_column("billing_events", "object_external_id")
