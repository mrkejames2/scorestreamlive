"""M19 HF8 advertisement artwork library integration."""
import uuid
from datetime import datetime, timezone
from alembic import op
import sqlalchemy as sa
revision="20261001_0036";down_revision="20260930_0035";branch_labels=None;depends_on=None

def upgrade():
    op.add_column("games",sa.Column("advertisement_artwork_id",sa.Uuid(),nullable=True))
    op.create_foreign_key("fk_games_advertisement_artwork_id","games","broadcast_artworks",["advertisement_artwork_id"],["id"],ondelete="RESTRICT")
    bind=op.get_bind();now=datetime.now(timezone.utc)
    games=bind.execute(sa.text("""SELECT id,club_id,advertisement_image_url,advertisement_updated_at FROM games WHERE club_id IS NOT NULL AND advertisement_image_url IS NOT NULL""")).mappings().all()
    cache={}
    for game in games:
        key=(game["club_id"],game["advertisement_image_url"]);aid=cache.get(key)
        if aid is None:
            aid=bind.execute(sa.text("SELECT id FROM broadcast_artworks WHERE club_id=:club_id AND image_url=:image_url"),{"club_id":game["club_id"],"image_url":game["advertisement_image_url"]}).scalar_one_or_none()
            if aid is None:
                aid=uuid.uuid4();ts=game["advertisement_updated_at"] or now
                bind.execute(sa.text("""INSERT INTO broadcast_artworks (id,club_id,name,image_url,created_by_user_id,created_at,updated_at) VALUES (:id,:club_id,:name,:image_url,NULL,:created_at,:updated_at)"""),{"id":aid,"club_id":game["club_id"],"name":f"Legacy Advertisement - {str(game['id'])[:8]}","image_url":game["advertisement_image_url"],"created_at":ts,"updated_at":ts})
            cache[key]=aid
        bind.execute(sa.text("UPDATE games SET advertisement_artwork_id=:artwork_id WHERE id=:game_id"),{"artwork_id":aid,"game_id":game["id"]})

def downgrade():
    op.drop_constraint("fk_games_advertisement_artwork_id","games",type_="foreignkey")
    op.drop_column("games","advertisement_artwork_id")
