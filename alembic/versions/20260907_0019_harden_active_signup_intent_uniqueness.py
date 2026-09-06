"""harden active signup intent uniqueness

Revision ID: 20260907_0019
Revises: 20260907_0018
"""
from alembic import op

revision="20260907_0019"
down_revision="20260907_0018"
branch_labels=None
depends_on=None

def upgrade():
    op.create_index(
        "uq_signup_intents_active_email",
        "signup_intents",
        ["email_normalized"],
        unique=True,
        postgresql_where="status IN ('PENDING','READY_FOR_CHECKOUT')",
    )

def downgrade():
    op.drop_index("uq_signup_intents_active_email", table_name="signup_intents")
