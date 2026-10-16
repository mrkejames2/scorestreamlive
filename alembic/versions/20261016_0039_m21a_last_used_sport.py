"""M21-A: persist each user's last-used sport.

Revision ID: 20261016_0039
Revises: 20261010_0038
"""
from alembic import op
import sqlalchemy as sa
revision = "20261016_0039"
down_revision = "20261010_0038"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("users", sa.Column("last_used_sport", sa.String(length=20), server_default="soccer", nullable=False))
    op.create_check_constraint("ck_users_last_used_sport", "users", "last_used_sport IN ('soccer', 'futsal')")

def downgrade():
    op.drop_constraint("ck_users_last_used_sport", "users", type_="check")
    op.drop_column("users", "last_used_sport")
