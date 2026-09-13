"""add Club branding domain
Revision ID: 20260913_0024
Revises: 20260910_0023
"""
from alembic import op
import sqlalchemy as sa
revision="20260913_0024"; down_revision="20260910_0023"; branch_labels=None; depends_on=None
def upgrade()->None:
    op.create_table("club_branding",sa.Column("id",sa.Uuid(),nullable=False),sa.Column("club_id",sa.Uuid(),nullable=False),sa.Column("display_name",sa.String(length=255),nullable=True),sa.Column("short_name",sa.String(length=100),nullable=True),sa.Column("logo_url",sa.String(length=500),nullable=True),sa.Column("primary_color",sa.String(length=7),nullable=True),sa.Column("secondary_color",sa.String(length=7),nullable=True),sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),sa.ForeignKeyConstraint(["club_id"],["clubs.id"],ondelete="CASCADE"),sa.PrimaryKeyConstraint("id"),sa.UniqueConstraint("club_id"))
    op.create_index("ix_club_branding_club_id","club_branding",["club_id"],unique=True)
def downgrade()->None:
    op.drop_index("ix_club_branding_club_id",table_name="club_branding"); op.drop_table("club_branding")
