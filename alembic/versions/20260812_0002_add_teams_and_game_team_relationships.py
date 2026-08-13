"""Add teams and game-team relationships

Revision ID: 20260812_0002
Revises: 20260812_0001
Create Date: 2026-08-12 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '20260812_0002'
down_revision: Union[str, None] = '20260812_0001'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create teams table
    op.create_table(
        'teams',
        sa.Column('id', sa.Uuid(as_uuid=True), nullable=False),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('short_name', sa.String(100), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.Column('updated_at', sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint('id'),
    )

    # Add team references to games (nullable to preserve existing M4 records)
    op.add_column('games', sa.Column('home_team_id', sa.Uuid(as_uuid=True), nullable=True))
    op.add_column('games', sa.Column('away_team_id', sa.Uuid(as_uuid=True), nullable=True))

    # Create foreign keys
    op.create_foreign_key('fk_games_home_team', 'games', 'teams', ['home_team_id'], ['id'])
    op.create_foreign_key('fk_games_away_team', 'games', 'teams', ['away_team_id'], ['id'])


def downgrade() -> None:
    op.drop_constraint('fk_games_away_team', 'games', type_='foreignkey')
    op.drop_constraint('fk_games_home_team', 'games', type_='foreignkey')
    op.drop_column('games', 'away_team_id')
    op.drop_column('games', 'home_team_id')
    op.drop_table('teams')