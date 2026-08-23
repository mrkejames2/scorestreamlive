"""add Club scope to Teams/Games and assignment tables

Revision ID: 20260824_0012
Revises: 20260824_0011
"""

from alembic import op
import sqlalchemy as sa

revision = "20260824_0012"
down_revision = "20260824_0011"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("teams", sa.Column("club_id", sa.Uuid(), nullable=True))
    op.create_foreign_key("fk_teams_club_id_clubs", "teams", "clubs", ["club_id"], ["id"], ondelete="RESTRICT")
    op.create_index("ix_teams_club_id", "teams", ["club_id"], unique=False)

    op.add_column("games", sa.Column("club_id", sa.Uuid(), nullable=True))
    op.create_foreign_key("fk_games_club_id_clubs", "games", "clubs", ["club_id"], ["id"], ondelete="RESTRICT")
    op.create_index("ix_games_club_id", "games", ["club_id"], unique=False)

    op.create_table(
        "team_managers",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("team_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["team_id"], ["teams.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("team_id", "user_id", name="uq_team_managers_team_user"),
    )
    op.create_index("ix_team_managers_team_id", "team_managers", ["team_id"])
    op.create_index("ix_team_managers_user_id", "team_managers", ["user_id"])

    op.create_table(
        "game_operators",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("game_id", sa.Uuid(), nullable=False),
        sa.Column("user_id", sa.Uuid(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["game_id"], ["games.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"], ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("game_id", "user_id", name="uq_game_operators_game_user"),
    )
    op.create_index("ix_game_operators_game_id", "game_operators", ["game_id"])
    op.create_index("ix_game_operators_user_id", "game_operators", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_game_operators_user_id", table_name="game_operators")
    op.drop_index("ix_game_operators_game_id", table_name="game_operators")
    op.drop_table("game_operators")
    op.drop_index("ix_team_managers_user_id", table_name="team_managers")
    op.drop_index("ix_team_managers_team_id", table_name="team_managers")
    op.drop_table("team_managers")
    op.drop_index("ix_games_club_id", table_name="games")
    op.drop_constraint("fk_games_club_id_clubs", "games", type_="foreignkey")
    op.drop_column("games", "club_id")
    op.drop_index("ix_teams_club_id", table_name="teams")
    op.drop_constraint("fk_teams_club_id_clubs", "teams", type_="foreignkey")
    op.drop_column("teams", "club_id")
