"""create_ai_results

Revision ID: 007
Revises: 006
Create Date: 2026-09-12 00:06:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "007"
down_revision: str | None = "006"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "ai_results",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("case_id", UUID(as_uuid=True), sa.ForeignKey("health_cases.id", ondelete="CASCADE"), nullable=False),
        sa.Column("model_name", sa.String(128), nullable=False),
        sa.Column("model_version", sa.String(64), nullable=False),
        sa.Column("input_type", sa.String(64), nullable=False),
        sa.Column("predictions", JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("top_prediction", sa.String(128), nullable=True),
        sa.Column("confidence", sa.Float(), nullable=True),
        sa.Column("inference_ms", sa.Integer(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_ai_results_case_id", "ai_results", ["case_id"])


def downgrade() -> None:
    op.drop_index("ix_ai_results_case_id", table_name="ai_results")
    op.drop_table("ai_results")
