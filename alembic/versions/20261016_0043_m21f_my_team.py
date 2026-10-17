"""M21-F R4: explicitly identify the operator's managed team in futsal games.

Revision ID: 20261016_0043
Revises: 20261016_0042
"""
from alembic import op
import sqlalchemy as sa
revision = '20261016_0043'
down_revision = '20261016_0042'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('games', sa.Column('my_team_id', sa.Uuid(), nullable=True))
    op.create_foreign_key('fk_games_my_team_id', 'games', 'teams', ['my_team_id'], ['id'], ondelete='RESTRICT')

def downgrade():
    op.drop_constraint('fk_games_my_team_id', 'games', type_='foreignkey')
    op.drop_column('games', 'my_team_id')
