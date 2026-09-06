"""add billing domain and entitlements

Revision ID: 20260907_0017
Revises: 20260905_0016
"""
import uuid
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa


revision = "20260907_0017"
down_revision = "20260905_0016"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "plans",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(64), nullable=False),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("description", sa.String(500), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code", name="uq_plans_code"),
    )

    op.create_table(
        "entitlements",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("code", sa.String(80), nullable=False),
        sa.Column("description", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("code", name="uq_entitlements_code"),
    )

    op.create_table(
        "plan_entitlements",
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("entitlement_id", sa.Uuid(), nullable=False),
        sa.Column("enabled", sa.Boolean(), nullable=False),
        sa.ForeignKeyConstraint(["entitlement_id"], ["entitlements.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["plan_id"], ["plans.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("plan_id", "entitlement_id"),
    )

    op.create_table(
        "subscriptions",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("club_id", sa.Uuid(), nullable=False),
        sa.Column("plan_id", sa.Uuid(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("provider", sa.String(32), nullable=True),
        sa.Column("current_period_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("current_period_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancel_at_period_end", sa.Boolean(), nullable=False),
        sa.Column("canceled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "status IN ('PENDING', 'ACTIVE', 'PAST_DUE', 'CANCELED', 'EXPIRED')",
            name="ck_subscriptions_status",
        ),
        sa.ForeignKeyConstraint(["club_id"], ["clubs.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["plan_id"], ["plans.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("club_id", name="uq_subscriptions_club_id"),
    )
    op.create_index("ix_subscriptions_plan_id", "subscriptions", ["plan_id"])

    op.create_table(
        "billing_external_references",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("resource_type", sa.String(40), nullable=False),
        sa.Column("external_id", sa.String(255), nullable=False),
        sa.Column("club_id", sa.Uuid(), nullable=True),
        sa.Column("subscription_id", sa.Uuid(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "(club_id IS NOT NULL AND subscription_id IS NULL) OR "
            "(club_id IS NULL AND subscription_id IS NOT NULL)",
            name="ck_billing_external_reference_owner",
        ),
        sa.ForeignKeyConstraint(["club_id"], ["clubs.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(
            ["subscription_id"], ["subscriptions.id"], ondelete="CASCADE"
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "provider",
            "resource_type",
            "external_id",
            name="uq_billing_external_reference",
        ),
    )
    op.create_index(
        "ix_billing_external_references_club_id",
        "billing_external_references",
        ["club_id"],
    )
    op.create_index(
        "ix_billing_external_references_subscription_id",
        "billing_external_references",
        ["subscription_id"],
    )

    op.create_table(
        "billing_events",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("provider", sa.String(32), nullable=False),
        sa.Column("external_event_id", sa.String(255), nullable=False),
        sa.Column("event_type", sa.String(160), nullable=False),
        sa.Column("processing_status", sa.String(20), nullable=False),
        sa.Column("attempt_count", sa.Integer(), nullable=False),
        sa.Column("payload_digest", sa.String(64), nullable=True),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("processed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.String(1000), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint(
            "processing_status IN ('RECEIVED', 'PROCESSED', 'FAILED', 'IGNORED')",
            name="ck_billing_events_processing_status",
        ),
        sa.CheckConstraint(
            "attempt_count >= 0",
            name="ck_billing_events_attempt_count",
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "provider",
            "external_event_id",
            name="uq_billing_event_provider_event",
        ),
    )

    # Seed only provider-neutral capability definitions. This is product
    # configuration, not production customer/payment/game data.
    entitlement_table = sa.table(
        "entitlements",
        sa.column("id", sa.Uuid()),
        sa.column("code", sa.String()),
        sa.column("description", sa.String()),
        sa.column("created_at", sa.DateTime(timezone=True)),
        sa.column("updated_at", sa.DateTime(timezone=True)),
    )
    now = datetime.now(timezone.utc)
    op.bulk_insert(
        entitlement_table,
        [
            {
                "id": uuid.uuid4(),
                "code": "CREATE_GAMES",
                "description": "Create and manage games.",
                "created_at": now,
                "updated_at": now,
            },
            {
                "id": uuid.uuid4(),
                "code": "MANAGE_USERS",
                "description": "Manage authorized organization users.",
                "created_at": now,
                "updated_at": now,
            },
            {
                "id": uuid.uuid4(),
                "code": "BROADCAST_OVERLAY",
                "description": "Use the public broadcast overlay.",
                "created_at": now,
                "updated_at": now,
            },
            {
                "id": uuid.uuid4(),
                "code": "CUSTOM_OVERLAY_BRANDING",
                "description": "Use organization-controlled branding in the overlay.",
                "created_at": now,
                "updated_at": now,
            },
        ],
    )


def downgrade():
    op.drop_table("billing_events")
    op.drop_index(
        "ix_billing_external_references_subscription_id",
        table_name="billing_external_references",
    )
    op.drop_index(
        "ix_billing_external_references_club_id",
        table_name="billing_external_references",
    )
    op.drop_table("billing_external_references")
    op.drop_index("ix_subscriptions_plan_id", table_name="subscriptions")
    op.drop_table("subscriptions")
    op.drop_table("plan_entitlements")
    op.drop_table("entitlements")
    op.drop_table("plans")
