"""M19 HF6 reusable broadcast artwork library."""

import uuid
from datetime import datetime, timezone

from alembic import op
import sqlalchemy as sa


revision = "20260925_0034"
down_revision = "20260922_0033"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "broadcast_artworks",
        sa.Column("id", sa.Uuid(), primary_key=True),
        sa.Column(
            "club_id",
            sa.Uuid(),
            sa.ForeignKey("clubs.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("image_url", sa.String(500), nullable=False),
        sa.Column(
            "created_by_user_id",
            sa.Uuid(),
            sa.ForeignKey("users.id", ondelete="SET NULL"),
            nullable=True,
        ),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint(
            "club_id",
            "image_url",
            name="uq_broadcast_artworks_club_image_url",
        ),
    )

    op.create_index(
        "ix_broadcast_artworks_club_id",
        "broadcast_artworks",
        ["club_id"],
    )

    op.add_column(
        "games",
        sa.Column("intro_artwork_id", sa.Uuid(), nullable=True),
    )
    op.add_column(
        "games",
        sa.Column("thank_you_artwork_id", sa.Uuid(), nullable=True),
    )

    op.create_foreign_key(
        "fk_games_intro_artwork_id",
        "games",
        "broadcast_artworks",
        ["intro_artwork_id"],
        ["id"],
        ondelete="RESTRICT",
    )
    op.create_foreign_key(
        "fk_games_thank_you_artwork_id",
        "games",
        "broadcast_artworks",
        ["thank_you_artwork_id"],
        ["id"],
        ondelete="RESTRICT",
    )

    bind = op.get_bind()
    now = datetime.now(timezone.utc)

    games = bind.execute(
        sa.text(
            """
            SELECT
                id,
                club_id,
                intro_image_url,
                thank_you_image_url,
                intro_updated_at,
                thank_you_updated_at
            FROM games
            WHERE club_id IS NOT NULL
              AND (
                    intro_image_url IS NOT NULL
                    OR thank_you_image_url IS NOT NULL
                  )
            """
        )
    ).mappings().all()

    artwork_cache = {}

    for game in games:
        candidates = (
            (
                "Welcome",
                game["intro_image_url"],
                game["intro_updated_at"],
                "intro_artwork_id",
            ),
            (
                "Thank You",
                game["thank_you_image_url"],
                game["thank_you_updated_at"],
                "thank_you_artwork_id",
            ),
        )

        for label, image_url, updated_at, game_column in candidates:
            if not image_url:
                continue

            key = (game["club_id"], image_url)
            artwork_id = artwork_cache.get(key)

            if artwork_id is None:
                artwork_id = bind.execute(
                    sa.text(
                        """
                        SELECT id
                        FROM broadcast_artworks
                        WHERE club_id = :club_id
                          AND image_url = :image_url
                        """
                    ),
                    {
                        "club_id": game["club_id"],
                        "image_url": image_url,
                    },
                ).scalar_one_or_none()

                if artwork_id is None:
                    artwork_id = uuid.uuid4()

                    bind.execute(
                        sa.text(
                            """
                            INSERT INTO broadcast_artworks (
                                id,
                                club_id,
                                name,
                                image_url,
                                created_by_user_id,
                                created_at,
                                updated_at
                            )
                            VALUES (
                                :id,
                                :club_id,
                                :name,
                                :image_url,
                                NULL,
                                :created_at,
                                :updated_at
                            )
                            """
                        ),
                        {
                            "id": artwork_id,
                            "club_id": game["club_id"],
                            "name": (
                                f"Legacy {label} - "
                                f"{str(game['id'])[:8]}"
                            ),
                            "image_url": image_url,
                            "created_at": updated_at or now,
                            "updated_at": updated_at or now,
                        },
                    )

                artwork_cache[key] = artwork_id

            if game_column == "intro_artwork_id":
                bind.execute(
                    sa.text(
                        """
                        UPDATE games
                        SET intro_artwork_id = :artwork_id
                        WHERE id = :game_id
                        """
                    ),
                    {
                        "artwork_id": artwork_id,
                        "game_id": game["id"],
                    },
                )
            else:
                bind.execute(
                    sa.text(
                        """
                        UPDATE games
                        SET thank_you_artwork_id = :artwork_id
                        WHERE id = :game_id
                        """
                    ),
                    {
                        "artwork_id": artwork_id,
                        "game_id": game["id"],
                    },
                )


def downgrade():
    op.drop_constraint(
        "fk_games_thank_you_artwork_id",
        "games",
        type_="foreignkey",
    )
    op.drop_constraint(
        "fk_games_intro_artwork_id",
        "games",
        type_="foreignkey",
    )

    op.drop_column("games", "thank_you_artwork_id")
    op.drop_column("games", "intro_artwork_id")

    op.drop_index(
        "ix_broadcast_artworks_club_id",
        table_name="broadcast_artworks",
    )
    op.drop_table("broadcast_artworks")
