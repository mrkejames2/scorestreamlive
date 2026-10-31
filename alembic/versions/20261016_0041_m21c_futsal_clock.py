"""M21-C: futsal clock configuration.

Revision ID: 20261016_0041
Revises: 20261016_0040
"""
from alembic import op
import sqlalchemy as sa
revision = '20261016_0041'
down_revision = '20261016_0040'
branch_labels = None
depends_on = None

def upgrade():
    op.create_table('futsal_clock_configs',
        sa.Column('game_id', sa.Uuid(), sa.ForeignKey('games.id', ondelete='CASCADE'), primary_key=True),
        sa.Column('period', sa.Integer(), nullable=False),
        sa.Column('clock_policy', sa.String(20), nullable=False),
        sa.Column('period_seconds', sa.Integer(), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.CheckConstraint('period BETWEEN 1 AND 2', name='ck_futsal_clock_period'),
        sa.CheckConstraint("clock_policy IN ('stop_clock', 'running_clock')", name='ck_futsal_clock_policy'),
        sa.CheckConstraint('period_seconds BETWEEN 60 AND 3600', name='ck_futsal_clock_duration'),
    )

def downgrade():
    op.drop_table('futsal_clock_configs')
