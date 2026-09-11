"""create_lab_samples

Revision ID: 009
Revises: 008
Create Date: 2026-09-12 00:08:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "009"
down_revision: str | None = "008"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "lab_samples",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("case_id", UUID(as_uuid=True), sa.ForeignKey("health_cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("sample_type", sa.String(64), nullable=False),
        sa.Column("sample_code", sa.String(64), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="COLLECTED"),
        sa.Column("lab_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="SET NULL"), nullable=True),
        sa.Column("collected_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("received_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("result", sa.Text(), nullable=True),
        sa.Column("result_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_lab_samples_sample_code", "lab_samples", ["sample_code"], unique=True)
    op.create_index("ix_lab_samples_case_id", "lab_samples", ["case_id"])
    op.create_index("ix_lab_samples_status", "lab_samples", ["status"])


def downgrade() -> None:
    op.drop_index("ix_lab_samples_status", table_name="lab_samples")
    op.drop_index("ix_lab_samples_case_id", table_name="lab_samples")
    op.drop_index("ix_lab_samples_sample_code", table_name="lab_samples")
    op.drop_table("lab_samples")
