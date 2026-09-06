"""add user password resets
Revision ID: 20260905_0016
Revises: 20260905_0015
"""
from alembic import op
import sqlalchemy as sa
revision="20260905_0016"
down_revision="20260905_0015"
branch_labels=None
depends_on=None

def upgrade():
    op.create_table("user_password_resets",
        sa.Column("id",sa.Uuid(),nullable=False),
        sa.Column("user_id",sa.Uuid(),nullable=False),
        sa.Column("token_hash",sa.String(64),nullable=False),
        sa.Column("expires_at",sa.DateTime(timezone=True),nullable=False),
        sa.Column("used_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("revoked_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),
        sa.ForeignKeyConstraint(["user_id"],["users.id"],ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("token_hash",name="uq_user_password_resets_token_hash"))
    op.create_index("ix_user_password_resets_user_id","user_password_resets",["user_id"])
    op.create_index("ix_user_password_resets_token_hash","user_password_resets",["token_hash"],unique=True)

def downgrade():
    op.drop_index("ix_user_password_resets_token_hash",table_name="user_password_resets")
    op.drop_index("ix_user_password_resets_user_id",table_name="user_password_resets")
    op.drop_table("user_password_resets")
