"""harden hosted checkout recovery

Revision ID: 20260907_0021
Revises: 20260907_0020
"""
from alembic import op

revision = "20260907_0021"
down_revision = "20260907_0020"
branch_labels = None
depends_on = None


def upgrade():
    op.create_index(
        "uq_billing_price_active_plan_provider",
        "billing_price_references",
        ["plan_id", "provider"],
        unique=True,
        postgresql_where="is_active IS TRUE",
    )
    op.create_index(
        "uq_checkout_attempt_active",
        "checkout_attempts",
        ["signup_intent_id", "plan_id", "provider"],
        unique=True,
        postgresql_where="status IN ('CREATING','OPEN')",
    )


def downgrade():
    op.drop_index("uq_checkout_attempt_active", table_name="checkout_attempts")
    op.drop_index("uq_billing_price_active_plan_provider", table_name="billing_price_references")
