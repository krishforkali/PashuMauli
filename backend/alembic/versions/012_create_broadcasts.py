"""create_broadcasts

Revision ID: 012
Revises: 011
Create Date: 2026-09-12 00:11:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "012"
down_revision: str | None = "011"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "broadcasts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("created_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("event_type", sa.String(64), nullable=False),
        sa.Column("title", sa.String(255), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("geometry", Geography("MULTIPOLYGON", srid=4326), nullable=False),
        sa.Column("recipient_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("channels", JSONB(), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column("status", sa.String(32), nullable=False, server_default="PENDING"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("completed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("ix_broadcasts_status", "broadcasts", ["status"])
    op.create_index("ix_broadcasts_created_by", "broadcasts", ["created_by"])
    op.execute("CREATE INDEX ix_broadcasts_geometry ON broadcasts USING GIST (geometry);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_broadcasts_geometry;")
    op.drop_index("ix_broadcasts_created_by", table_name="broadcasts")
    op.drop_index("ix_broadcasts_status", table_name="broadcasts")
    op.drop_table("broadcasts")
