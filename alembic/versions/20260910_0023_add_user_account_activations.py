"""add post-purchase user account activations

Revision ID: 20260910_0023
Revises: 20260907_0022
"""
from alembic import op
import sqlalchemy as sa

revision = "20260910_0023"
down_revision = "20260907_0022"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "user_account_activations",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("token_hash", sa.String(length=64), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash"),
    )
    op.create_index(
        "ix_user_account_activations_user_id",
        "user_account_activations",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_account_activations_token_hash",
        "user_account_activations",
        ["token_hash"],
        unique=True,
    )
    op.create_index(
        "uq_user_account_activation_pending_user",
        "user_account_activations",
        ["user_id"],
        unique=True,
        postgresql_where=sa.text("used_at IS NULL AND revoked_at IS NULL"),
    )


def downgrade() -> None:
    op.drop_index(
        "uq_user_account_activation_pending_user",
        table_name="user_account_activations",
    )
    op.drop_index(
        "ix_user_account_activations_token_hash",
        table_name="user_account_activations",
    )
    op.drop_index(
        "ix_user_account_activations_user_id",
        table_name="user_account_activations",
    )
    op.drop_table("user_account_activations")
