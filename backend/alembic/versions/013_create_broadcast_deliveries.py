"""create_broadcast_deliveries

Revision ID: 013
Revises: 012
Create Date: 2026-09-12 00:12:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "013"
down_revision: str | None = "012"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "broadcast_deliveries",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("broadcast_id", UUID(as_uuid=True), sa.ForeignKey("broadcasts.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("channel", sa.String(32), nullable=False),
        sa.Column("status", sa.String(32), nullable=False, server_default="PENDING"),
        sa.Column("provider_message_id", sa.String(128), nullable=True),
        sa.Column("attempts", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("sent_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("delivered_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("broadcast_id", "user_id", "channel", name="uq_broadcast_deliveries_target"),
    )
    op.create_index("ix_broadcast_deliveries_bcast_status", "broadcast_deliveries", ["broadcast_id", "status"])
    op.create_index("ix_broadcast_deliveries_user_id", "broadcast_deliveries", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_broadcast_deliveries_user_id", table_name="broadcast_deliveries")
    op.drop_index("ix_broadcast_deliveries_bcast_status", table_name="broadcast_deliveries")
    op.drop_table("broadcast_deliveries")
