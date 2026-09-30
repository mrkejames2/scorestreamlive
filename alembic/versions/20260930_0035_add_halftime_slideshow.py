"""M19 HF7 halftime slideshow."""
from alembic import op
import sqlalchemy as sa
revision="20260930_0035";down_revision="20260925_0034";branch_labels=None;depends_on=None
def upgrade():
 op.create_table("game_halftime_slideshows",sa.Column("game_id",sa.Uuid(),sa.ForeignKey("games.id",ondelete="CASCADE"),primary_key=True),sa.Column("enabled",sa.Boolean(),nullable=False,server_default=sa.false()),sa.Column("interval_seconds",sa.Integer(),nullable=False,server_default="10"),sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),sa.CheckConstraint("interval_seconds IN (5,10,15,20,30)",name="ck_halftime_slideshow_interval"))
 op.create_table("game_halftime_slideshow_slides",sa.Column("id",sa.Uuid(),primary_key=True),sa.Column("game_id",sa.Uuid(),sa.ForeignKey("game_halftime_slideshows.game_id",ondelete="CASCADE"),nullable=False),sa.Column("artwork_id",sa.Uuid(),sa.ForeignKey("broadcast_artworks.id",ondelete="RESTRICT"),nullable=False),sa.Column("position",sa.Integer(),nullable=False),sa.Column("created_at",sa.DateTime(timezone=True),nullable=False),sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False),sa.UniqueConstraint("game_id","position",name="uq_halftime_slideshow_game_position"),sa.UniqueConstraint("game_id","artwork_id",name="uq_halftime_slideshow_game_artwork"))
 op.create_index("ix_halftime_slideshow_slides_game_id","game_halftime_slideshow_slides",["game_id"]);op.create_index("ix_halftime_slideshow_slides_artwork_id","game_halftime_slideshow_slides",["artwork_id"])
 op.drop_constraint("ck_game_broadcast_presentations_scene","game_broadcast_presentations",type_="check")
 op.create_check_constraint("ck_game_broadcast_presentations_scene","game_broadcast_presentations","scene IN ('intro','live','advertisement','halftime_slideshow','summary','thank_you')")
def downgrade():
 op.drop_constraint("ck_game_broadcast_presentations_scene","game_broadcast_presentations",type_="check")
 op.create_check_constraint("ck_game_broadcast_presentations_scene","game_broadcast_presentations","scene IN ('intro','live','advertisement','summary','thank_you')")
 op.drop_index("ix_halftime_slideshow_slides_artwork_id",table_name="game_halftime_slideshow_slides");op.drop_index("ix_halftime_slideshow_slides_game_id",table_name="game_halftime_slideshow_slides");op.drop_table("game_halftime_slideshow_slides");op.drop_table("game_halftime_slideshows")
