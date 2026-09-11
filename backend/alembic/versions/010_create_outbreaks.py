"""create_outbreaks

Revision ID: 010
Revises: 009
Create Date: 2026-09-12 00:09:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "010"
down_revision: str | None = "009"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "outbreaks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("disease", sa.String(128), nullable=False),
        sa.Column("risk_level", sa.String(32), nullable=False, server_default="HIGH"),
        sa.Column("geometry", Geography("MULTIPOLYGON", srid=4326), nullable=False),
        sa.Column("case_count", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("detected_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="ACTIVE"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_outbreaks_status", "outbreaks", ["status"])
    op.create_index("ix_outbreaks_disease", "outbreaks", ["disease"])
    op.execute("CREATE INDEX ix_outbreaks_geometry ON outbreaks USING GIST (geometry);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_outbreaks_geometry;")
    op.drop_index("ix_outbreaks_disease", table_name="outbreaks")
    op.drop_index("ix_outbreaks_status", table_name="outbreaks")
    op.drop_table("outbreaks")
