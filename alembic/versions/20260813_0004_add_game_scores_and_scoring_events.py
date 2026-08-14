"""Add game scores and scoring_events table.

Revision ID: 20260813_0004
Revises: 20260813_0003
Create Date: 2026-08-13 23:00:00.000000+00:00

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "20260813_0004"
down_revision: Union[str, None] = '20260813_0003'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Add home_score to games
    op.add_column(
        'games',
        sa.Column('home_score', sa.Integer(), nullable=False, server_default='0')
    )

    # Add away_score to games
    op.add_column(
        'games',
        sa.Column('away_score', sa.Integer(), nullable=False, server_default='0')
    )

    # Create scoring_events table
    op.create_table(
        'scoring_events',
        sa.Column('id', sa.UUID(), nullable=False),
        sa.Column('game_id', sa.UUID(), nullable=False),
        sa.Column('team_id', sa.UUID(), nullable=False),
        sa.Column('player_id', sa.UUID(), nullable=True),
        sa.Column('event_type', sa.String(length=50), nullable=False),
        sa.Column('created_at', sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(['game_id'], ['games.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['team_id'], ['teams.id'], ondelete='RESTRICT'),
        sa.ForeignKeyConstraint(['player_id'], ['players.id'], ondelete='RESTRICT'),
        sa.PrimaryKeyConstraint('id'),
    )

    # Create index
    op.create_index('ix_scoring_events_game_id', 'scoring_events', ['game_id'])


def downgrade() -> None:
    op.drop_index('ix_scoring_events_game_id', table_name='scoring_events')
    op.drop_table('scoring_events')
    op.drop_column('games', 'away_score')
    op.drop_column('games', 'home_score')