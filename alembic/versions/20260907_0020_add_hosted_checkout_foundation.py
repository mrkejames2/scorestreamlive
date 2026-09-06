"""add hosted checkout foundation

Revision ID: 20260907_0020
Revises: 20260907_0019
"""
from alembic import op
import sqlalchemy as sa

revision = "20260907_0020"
down_revision = "20260907_0019"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("billing_external_references", sa.Column("signup_intent_id", sa.Uuid(), nullable=True))
    op.create_foreign_key(
        "fk_billing_external_references_signup_intent",
        "billing_external_references",
        "signup_intents",
        ["signup_intent_id"],
        ["id"],
        ondelete="CASCADE",
    )
    op.create_index(
        "ix_billing_external_references_signup_intent_id",
        "billing_external_references",
        ["signup_intent_id"],
    )
    op.drop_constraint("ck_billing_external_reference_owner", "billing_external_references", type_="check")
    op.create_check_constraint(
        "ck_billing_external_reference_owner",
        "billing_external_references",
        "((CASE WHEN club_id IS NOT NULL THEN 1 ELSE 0 END) + "
        "(CASE WHEN subscription_id IS NOT NULL THEN 1 ELSE 0 END) + "
        "(CASE WHEN signup_intent_id IS NOT NULL THEN 1 ELSE 0 END)) = 1",
    )

    op.create_table(
        "billing_price_references",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("plan_id", sa.Uuid(), sa.ForeignKey("plans.id", ondelete="CASCADE"), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("external_price_id", sa.String(length=255), nullable=False),
        sa.Column("currency", sa.String(length=3), nullable=False),
        sa.Column("billing_interval", sa.String(length=16), nullable=False),
        sa.Column("unit_amount_minor", sa.Integer(), nullable=False),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.true()),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("provider", "external_price_id", name="uq_billing_price_external"),
        sa.CheckConstraint("unit_amount_minor >= 0", name="ck_billing_price_nonnegative"),
        sa.CheckConstraint("billing_interval IN ('month','year')", name="ck_billing_price_interval"),
    )
    op.create_index("ix_billing_price_references_plan_id", "billing_price_references", ["plan_id"])

    op.create_table(
        "checkout_attempts",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column("signup_intent_id", sa.Uuid(), sa.ForeignKey("signup_intents.id", ondelete="CASCADE"), nullable=False),
        sa.Column("plan_id", sa.Uuid(), sa.ForeignKey("plans.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("provider", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("idempotency_key", sa.String(length=160), nullable=False),
        sa.Column("checkout_url", sa.String(length=2048), nullable=True),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_error", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("idempotency_key", name="uq_checkout_attempt_idempotency"),
        sa.CheckConstraint(
            "status IN ('CREATING','OPEN','EXPIRED','COMPLETED','FAILED','CANCELED')",
            name="ck_checkout_attempt_status",
        ),
    )
    op.create_index("ix_checkout_attempts_signup_intent_id", "checkout_attempts", ["signup_intent_id"])


def downgrade():
    op.drop_index("ix_checkout_attempts_signup_intent_id", table_name="checkout_attempts")
    op.drop_table("checkout_attempts")
    op.drop_index("ix_billing_price_references_plan_id", table_name="billing_price_references")
    op.drop_table("billing_price_references")
    op.drop_constraint("ck_billing_external_reference_owner", "billing_external_references", type_="check")
    op.create_check_constraint(
        "ck_billing_external_reference_owner",
        "billing_external_references",
        "(club_id IS NOT NULL AND subscription_id IS NULL) OR (club_id IS NULL AND subscription_id IS NOT NULL)",
    )
    op.drop_index("ix_billing_external_references_signup_intent_id", table_name="billing_external_references")
    op.drop_constraint("fk_billing_external_references_signup_intent", "billing_external_references", type_="foreignkey")
    op.drop_column("billing_external_references", "signup_intent_id")
