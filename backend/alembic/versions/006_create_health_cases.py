"""create_health_cases

Revision ID: 006
Revises: 005
Create Date: 2026-09-12 00:05:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from geoalchemy2 import Geography
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "006"
down_revision: str | None = "005"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "health_cases",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("client_id", UUID(as_uuid=True), nullable=True),
        sa.Column("animal_id", UUID(as_uuid=True), sa.ForeignKey("animals.id", ondelete="SET NULL"), nullable=True),
        sa.Column("farmer_id", UUID(as_uuid=True), sa.ForeignKey("farmers.id", ondelete="SET NULL"), nullable=True),
        sa.Column("reported_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("source", sa.String(32), nullable=False),
        sa.Column("symptoms", JSONB(), nullable=False, server_default=sa.text("'[]'::jsonb")),
        sa.Column("suspected_disease", sa.String(128), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("risk_score", sa.Float(), nullable=True),
        sa.Column("risk_level", sa.String(32), nullable=False, server_default="UNKNOWN"),
        sa.Column("status", sa.String(32), nullable=False, server_default="OPEN"),
        sa.Column("location", Geography("POINT", srid=4326), nullable=True),
        sa.Column("ai_model_version", sa.String(64), nullable=True),
        sa.Column("advisory_version", sa.String(64), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_health_cases_client_id", "health_cases", ["client_id"], unique=True)
    op.create_index("ix_health_cases_status", "health_cases", ["status"])
    op.create_index("ix_health_cases_created_at", "health_cases", ["created_at"])
    op.create_index("ix_health_cases_animal_id", "health_cases", ["animal_id"])
    op.create_index("ix_health_cases_farmer_id", "health_cases", ["farmer_id"])
    op.execute("CREATE INDEX ix_health_cases_location ON health_cases USING GIST (location);")


def downgrade() -> None:
    op.execute("DROP INDEX IF EXISTS ix_health_cases_location;")
    op.drop_index("ix_health_cases_farmer_id", table_name="health_cases")
    op.drop_index("ix_health_cases_animal_id", table_name="health_cases")
    op.drop_index("ix_health_cases_created_at", table_name="health_cases")
    op.drop_index("ix_health_cases_status", table_name="health_cases")
    op.drop_index("ix_health_cases_client_id", table_name="health_cases")
    op.drop_table("health_cases")
