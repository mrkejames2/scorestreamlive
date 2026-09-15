"""harden subscription lifecycle ordering and recovery

Revision ID: 20260915_0025
Revises: 20260913_0024
"""
from alembic import op
import sqlalchemy as sa

revision = "20260915_0025"
down_revision = "20260913_0024"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column(
        "subscriptions",
        sa.Column("last_provider_event_created_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "subscriptions",
        sa.Column("last_provider_event_id", sa.String(length=255), nullable=True),
    )

def downgrade():
    op.drop_column("subscriptions", "last_provider_event_id")
    op.drop_column("subscriptions", "last_provider_event_created_at")
