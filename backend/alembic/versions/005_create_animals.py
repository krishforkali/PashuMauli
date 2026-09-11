"""create_animals

Revision ID: 005
Revises: 004
Create Date: 2026-09-12 00:04:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "005"
down_revision: str | None = "004"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "animals",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("ear_tag_id", sa.String(64), nullable=False),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id", ondelete="CASCADE"), nullable=False),
        sa.Column("species", sa.String(64), nullable=False),
        sa.Column("breed", sa.String(128), nullable=True),
        sa.Column("sex", sa.String(16), nullable=True),
        sa.Column("date_of_birth", sa.Date(), nullable=True),
        sa.Column("status", sa.String(32), nullable=False, server_default="ACTIVE"),
        sa.Column("location", Geography("POINT", srid=4326), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_animals_ear_tag_id", "animals", ["ear_tag_id"], unique=True)
    op.create_index("ix_animals_farmer_id", "animals", ["farmer_id"])
    op.execute("CREATE INDEX ix_animals_location ON animals USING GIST (location);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_animals_location;")
    op.drop_index("ix_animals_farmer_id", table_name="animals")
    op.drop_index("ix_animals_ear_tag_id", table_name="animals")
    op.drop_table("animals")
