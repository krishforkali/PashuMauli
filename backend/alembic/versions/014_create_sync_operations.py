"""create_sync_operations

Revision ID: 014
Revises: 013
Create Date: 2026-09-12 00:13:00.000000

"""
from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "014"
down_revision: str | None = "013"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "sync_operations",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("client_id", UUID(as_uuid=True), nullable=False),
        sa.Column("user_id", UUID(as_uuid=True), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("entity_type", sa.String(64), nullable=False),
        sa.Column("entity_id", UUID(as_uuid=True), nullable=False),
        sa.Column("operation_type", sa.String(32), nullable=False),
        sa.Column("payload", JSONB(), nullable=False, server_default=sa.text("'{}'::jsonb")),
        sa.Column("status", sa.String(32), nullable=False, server_default="PENDING"),
        sa.Column("attempt_count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("last_error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
    )
    op.create_index("ix_sync_operations_client_id", "sync_operations", ["client_id"], unique=True)
    op.create_index("ix_sync_operations_status_created", "sync_operations", ["status", "created_at"])
    op.create_index("ix_sync_operations_user_id", "sync_operations", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_sync_operations_user_id", table_name="sync_operations")
    op.drop_index("ix_sync_operations_status_created", table_name="sync_operations")
    op.drop_index("ix_sync_operations_client_id", table_name="sync_operations")
    op.drop_table("sync_operations")
