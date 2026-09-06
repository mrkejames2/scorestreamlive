"""add public signup intents
Revision ID: 20260907_0018
Revises: 20260907_0017
"""
from alembic import op
import sqlalchemy as sa
revision="20260907_0018"
down_revision="20260907_0017"
branch_labels=None
depends_on=None
def upgrade():
    op.create_table("signup_intents",
        sa.Column("id",sa.Uuid(),nullable=False),
        sa.Column("email",sa.String(320),nullable=False),
        sa.Column("email_normalized",sa.String(320),nullable=False),
        sa.Column("first_name",sa.String(100),nullable=False),
        sa.Column("last_name",sa.String(100),nullable=False),
        sa.Column("organization_name",sa.String(180),nullable=False),
        sa.Column("status",sa.String(24),nullable=False),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),
        sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),
        sa.Column("expires_at",sa.DateTime(timezone=True),nullable=False),
        sa.Column("checkout_started_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("completed_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("source",sa.String(80),nullable=True),
        sa.CheckConstraint("status IN ('PENDING','READY_FOR_CHECKOUT','CHECKOUT_STARTED','COMPLETED','EXPIRED','CANCELED')",name="ck_signup_intents_status"),
        sa.PrimaryKeyConstraint("id"))
    op.create_index("ix_signup_intents_email_normalized","signup_intents",["email_normalized"])
    op.create_index("ix_signup_intents_status","signup_intents",["status"])
def downgrade():
    op.drop_index("ix_signup_intents_status",table_name="signup_intents")
    op.drop_index("ix_signup_intents_email_normalized",table_name="signup_intents")
    op.drop_table("signup_intents")
