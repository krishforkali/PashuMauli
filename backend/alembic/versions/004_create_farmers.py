"""create_farmers

Revision ID: 004
Revises: 003
Create Date: 2026-09-12 00:03:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "004"
down_revision: str | None = "003"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "farmers",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("phone", sa.String(32), nullable=False),
        sa.Column("preferred_language", sa.String(16), nullable=False, server_default="mr"),
        sa.Column("village_id", UUID(as_uuid=True), sa.ForeignKey("villages.id", ondelete="SET NULL"), nullable=True),
        sa.Column("location", Geography("POINT", srid=4326), nullable=True),
        sa.Column("address_text", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_farmers_phone", "farmers", ["phone"])
    op.create_index("ix_farmers_village_id", "farmers", ["village_id"])
    op.execute("CREATE INDEX ix_farmers_location ON farmers USING GIST (location);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_farmers_location;")
    op.drop_index("ix_farmers_village_id", table_name="farmers")
    op.drop_index("ix_farmers_phone", table_name="farmers")
    op.drop_table("farmers")
