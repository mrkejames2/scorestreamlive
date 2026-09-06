"""add user invitations
Revision ID: 20260905_0015
Revises: 20260904_0014
"""
from alembic import op
import sqlalchemy as sa
revision="20260905_0015"
down_revision="20260904_0014"
branch_labels=None
depends_on=None

def upgrade():
    op.create_table("user_invitations",
        sa.Column("id",sa.Uuid(),nullable=False), sa.Column("club_id",sa.Uuid(),nullable=False),
        sa.Column("email",sa.String(320),nullable=False), sa.Column("display_name",sa.String(255),nullable=True),
        sa.Column("club_role",sa.String(20),nullable=False), sa.Column("token_hash",sa.String(64),nullable=False),
        sa.Column("created_by_user_id",sa.Uuid(),nullable=False), sa.Column("expires_at",sa.DateTime(timezone=True),nullable=False),
        sa.Column("accepted_at",sa.DateTime(timezone=True),nullable=True), sa.Column("revoked_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False), sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),
        sa.CheckConstraint("club_role IN ('MANAGER', 'OPERATOR')",name="ck_user_invitations_club_role"),
        sa.ForeignKeyConstraint(["club_id"],["clubs.id"],ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["created_by_user_id"],["users.id"],ondelete="RESTRICT"),
        sa.PrimaryKeyConstraint("id"), sa.UniqueConstraint("token_hash",name="uq_user_invitations_token_hash"))
    op.create_index("ix_user_invitations_club_id","user_invitations",["club_id"])
    op.create_index("ix_user_invitations_email","user_invitations",["email"])
    op.create_index("ix_user_invitations_token_hash","user_invitations",["token_hash"],unique=True)
    op.create_index("ix_user_invitations_created_by_user_id","user_invitations",["created_by_user_id"])

def downgrade():
    op.drop_index("ix_user_invitations_created_by_user_id",table_name="user_invitations")
    op.drop_index("ix_user_invitations_token_hash",table_name="user_invitations")
    op.drop_index("ix_user_invitations_email",table_name="user_invitations")
    op.drop_index("ix_user_invitations_club_id",table_name="user_invitations")
    op.drop_table("user_invitations")
