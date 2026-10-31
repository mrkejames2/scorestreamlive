"""M21-B sport-aware teams and games.

Revision ID: 20261016_0040
Revises: 20261016_0039
"""
from alembic import op
import sqlalchemy as sa
revision = '20261016_0040'
down_revision = '20261016_0039'
branch_labels = None
depends_on = None

def upgrade():
    op.add_column('teams', sa.Column('sport', sa.String(20), nullable=False, server_default='soccer'))
    op.add_column('games', sa.Column('sport', sa.String(20), nullable=False, server_default='soccer'))
    op.create_check_constraint('ck_teams_sport', 'teams', "sport IN ('soccer', 'futsal')")
    op.create_check_constraint('ck_games_sport', 'games', "sport IN ('soccer', 'futsal')")
    op.create_index('ix_teams_club_sport', 'teams', ['club_id', 'sport'])
    op.create_index('ix_games_club_sport', 'games', ['club_id', 'sport'])

def downgrade():
    op.drop_index('ix_games_club_sport', table_name='games')
    op.drop_index('ix_teams_club_sport', table_name='teams')
    op.drop_constraint('ck_games_sport', 'games', type_='check')
    op.drop_constraint('ck_teams_sport', 'teams', type_='check')
    op.drop_column('games', 'sport')
    op.drop_column('teams', 'sport')
