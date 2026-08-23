"""add clubs and single-club user membership

Revision ID: 20260824_0011
Revises: 20260824_0010
"""
from alembic import op
import sqlalchemy as sa
revision = "20260824_0011"
down_revision = "20260824_0010"
branch_labels = None
depends_on = None

def upgrade() -> None:
    op.create_table(
        "clubs",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("name", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )
    op.add_column("users", sa.Column("club_id", sa.Uuid(), nullable=True))
    op.add_column("users", sa.Column("club_role", sa.String(length=20), nullable=True))
    op.create_foreign_key("fk_users_club_id_clubs", "users", "clubs", ["club_id"], ["id"], ondelete="RESTRICT")
    op.create_index("ix_users_club_id", "users", ["club_id"], unique=False)
    op.create_check_constraint("ck_users_club_role", "users", "club_role IS NULL OR club_role IN ('DIRECTOR', 'MANAGER', 'OPERATOR')")

def downgrade() -> None:
    op.drop_constraint("ck_users_club_role", "users", type_="check")
    op.drop_index("ix_users_club_id", table_name="users")
    op.drop_constraint("fk_users_club_id_clubs", "users", type_="foreignkey")
    op.drop_column("users", "club_role")
    op.drop_column("users", "club_id")
    op.drop_table("clubs")
