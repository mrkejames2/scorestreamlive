"""add sponsor domain

Revision ID: 20260917_0027
Revises: 20260915_0026
"""
from alembic import op
import sqlalchemy as sa

revision="20260917_0027"
down_revision="20260915_0026"
branch_labels=None
depends_on=None

def upgrade()->None:
    op.create_table(
        "sponsors",
        sa.Column("id",sa.Uuid(),nullable=False),
        sa.Column("club_id",sa.Uuid(),nullable=False),
        sa.Column("name",sa.String(length=255),nullable=False),
        sa.Column("website_url",sa.String(length=2048),nullable=True),
        sa.Column("artwork_url",sa.String(length=500),nullable=True),
        sa.Column("is_active",sa.Boolean(),server_default=sa.true(),nullable=False),
        sa.Column("display_order",sa.Integer(),server_default="0",nullable=False),
        sa.Column("starts_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("ends_at",sa.DateTime(timezone=True),nullable=True),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),
        sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),
        sa.CheckConstraint("ends_at IS NULL OR starts_at IS NULL OR ends_at >= starts_at",name="ck_sponsors_valid_date_window"),
        sa.ForeignKeyConstraint(["club_id"],["clubs.id"],ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_sponsors_club_id","sponsors",["club_id"],unique=False)

def downgrade()->None:
    op.drop_index("ix_sponsors_club_id",table_name="sponsors")
    op.drop_table("sponsors")
