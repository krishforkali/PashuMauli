"""create_gis_references

Revision ID: 003
Revises: 002
Create Date: 2026-09-12 00:02:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "003"
down_revision: str | None = "002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    # 1. districts
    op.create_table(
        "districts",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("code", sa.String(32), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("state", sa.String(255), nullable=False, server_default="Maharashtra"),
        sa.Column("geometry", Geography("MULTIPOLYGON", srid=4326), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_districts_code", "districts", ["code"], unique=True)

    # 2. blocks
    op.create_table(
        "blocks",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("district_id", UUID(as_uuid=True), sa.ForeignKey("districts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(32), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("geometry", Geography("MULTIPOLYGON", srid=4326), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_blocks_code", "blocks", ["code"], unique=True)
    op.create_index("ix_blocks_district_id", "blocks", ["district_id"])

    # 3. villages
    op.create_table(
        "villages",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("block_id", UUID(as_uuid=True), sa.ForeignKey("blocks.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(32), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("geometry", Geography("MULTIPOLYGON", srid=4326), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_villages_code", "villages", ["code"], unique=True)
    op.create_index("ix_villages_block_id", "villages", ["block_id"])

    # FK from users.village_id to villages.id
    op.create_foreign_key(
        "fk_users_village_id",
        "users",
        "villages",
        ["village_id"],
        ["id"],
        ondelete="SET NULL",
    )


def downgrade() -> None:
    op.drop_constraint("fk_users_village_id", "users", type_="foreignkey")
    op.drop_index("ix_villages_block_id", table_name="villages")
    op.drop_index("ix_villages_code", table_name="villages")
    op.drop_table("villages")
    op.drop_index("ix_blocks_district_id", table_name="blocks")
    op.drop_index("ix_blocks_code", table_name="blocks")
    op.drop_table("blocks")
    op.drop_index("ix_districts_code", table_name="districts")
    op.drop_table("districts")
