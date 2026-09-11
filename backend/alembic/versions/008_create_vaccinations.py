"""create_vaccinations

Revision ID: 008
Revises: 007
Create Date: 2026-09-12 00:07:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "008"
down_revision: str | None = "007"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "vaccinations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("animal_id", UUID(as_uuid=True), sa.ForeignKey("animals.id", ondelete="CASCADE"), nullable=False),
        sa.Column("vaccine", sa.String(128), nullable=False),
        sa.Column("dose", sa.String(64), nullable=True),
        sa.Column("administered_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("next_due_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("administered_by", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("batch_number", sa.String(64), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_vaccinations_animal_id", "vaccinations", ["animal_id"])
    op.create_index("ix_vaccinations_administered_at", "vaccinations", ["administered_at"])


def downgrade() -> None:
    op.drop_index("ix_vaccinations_administered_at", table_name="vaccinations")
    op.drop_index("ix_vaccinations_animal_id", table_name="vaccinations")
    op.drop_table("vaccinations")
