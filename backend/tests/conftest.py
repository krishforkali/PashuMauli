"""Shared pytest fixtures for Phase 2 tests.

Teardown uses:
1. Sync psycopg2 connection with correct FK deletion hierarchy.
2. Async engine disposal between tests so connection pools don't leak across event loops.
"""
import os

import psycopg2
import pytest
import pytest_asyncio

from app.db.base import async_engine


def _sync_db():
    """Return a psycopg2 connection using the same DSN as the backend."""
    dsn = os.environ.get(
        "DATABASE_URL",
        "postgresql://pashu:pashu@postgres:5432/pashumauli",
    )
    # Strip asyncpg/psycopg2 driver prefix if present
    for prefix in ("postgresql+asyncpg://", "postgresql+psycopg2://"):
        if dsn.startswith(prefix):
            dsn = "postgresql://" + dsn[len(prefix):]
    return psycopg2.connect(dsn)


@pytest_asyncio.fixture(autouse=True)
async def cleanup_async_engine():
    """Dispose of the async engine pool after each async test to prevent loop conflicts."""
    yield
    await async_engine.dispose()


@pytest.fixture(autouse=True)
def cleanup_test_data():
    """Delete test-scoped rows after each test using a sync connection in strict FK order."""
    yield
    conn = _sync_db()
    conn.autocommit = True
    cur = conn.cursor()
    try:
        # 1. AI results
        cur.execute(
            "DELETE FROM ai_results WHERE model_name LIKE 'Test%' OR case_id IN ("
            "  SELECT id FROM health_cases WHERE farmer_id IN ("
            "    SELECT id FROM farmers WHERE phone LIKE '07%' OR name LIKE 'Test%' OR name LIKE 'Case%' OR name LIKE 'Animal%'"
            "  ) OR reported_by IN (SELECT id FROM users WHERE phone LIKE '+99%')"
            ")"
        )
        # 2. Health cases
        cur.execute(
            "DELETE FROM health_cases WHERE farmer_id IN ("
            "  SELECT id FROM farmers WHERE phone LIKE '07%' OR name LIKE 'Test%' OR name LIKE 'Case%' OR name LIKE 'Animal%'"
            ") OR reported_by IN (SELECT id FROM users WHERE phone LIKE '+99%')"
            " OR suspected_disease LIKE 'Test%'"
        )
        # 3. Animals
        cur.execute(
            "DELETE FROM animals WHERE farmer_id IN ("
            "  SELECT id FROM farmers WHERE phone LIKE '07%' OR name LIKE 'Test%' OR name LIKE 'Case%' OR name LIKE 'Animal%'"
            ") OR ear_tag_id LIKE 'TEST%'"
        )
        # 4. Farmers
        cur.execute(
            "DELETE FROM farmers WHERE phone LIKE '07%' OR name LIKE 'Test%' OR name LIKE 'Case%' OR name LIKE 'Animal%'"
            " OR user_id IN (SELECT id FROM users WHERE phone LIKE '+99%')"
        )
        # 5. Audit logs
        cur.execute(
            "DELETE FROM audit_logs WHERE actor_user_id IN ("
            "  SELECT id FROM users WHERE phone LIKE '+99%'"
            ")"
        )
        # 6. Users
        cur.execute(
            "DELETE FROM users WHERE phone LIKE '+99%' OR phone LIKE '0000%'"
        )
    finally:
        cur.close()
        conn.close()
