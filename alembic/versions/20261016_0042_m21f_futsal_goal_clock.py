"""M21-F R3: persist period and countdown remaining on futsal goals.
Revision ID: 20261016_0042
Revises: 20261016_0041
"""
from alembic import op
import sqlalchemy as sa
revision = '20261016_0042'
down_revision = '20261016_0041'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('scoring_events', sa.Column('futsal_period', sa.Integer(), nullable=True))
    op.add_column('scoring_events', sa.Column('futsal_remaining_seconds', sa.Integer(), nullable=True))
    op.create_check_constraint('ck_scoring_events_futsal_period', 'scoring_events', 'futsal_period IS NULL OR futsal_period BETWEEN 1 AND 2')
    op.create_check_constraint('ck_scoring_events_futsal_remaining', 'scoring_events', 'futsal_remaining_seconds IS NULL OR futsal_remaining_seconds >= 0')

def downgrade():
    op.drop_constraint('ck_scoring_events_futsal_remaining', 'scoring_events', type_='check')
    op.drop_constraint('ck_scoring_events_futsal_period', 'scoring_events', type_='check')
    op.drop_column('scoring_events', 'futsal_remaining_seconds')
    op.drop_column('scoring_events', 'futsal_period')
