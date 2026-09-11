"""Integration tests for database migrations and foundational endpoints."""
import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine

from app.core.config import get_settings
from app.main import app

settings = get_settings()

EXPECTED_TABLES = {
    "users",
    "districts",
    "blocks",
    "villages",
    "farmers",
    "animals",
    "health_cases",
    "ai_results",
    "vaccinations",
    "lab_samples",
    "outbreaks",
    "notifications",
    "broadcasts",
    "broadcast_deliveries",
    "sync_operations",
    "audit_logs",
}


@pytest.mark.asyncio
async def test_health_endpoint() -> None:
    """Test that GET /health returns 200 and expected payload."""
    async with AsyncClient(
        transport=ASGITransport(app=app),  # type: ignore[arg-type]
        base_url="http://test",
    ) as client:
        response = await client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert data["app"] == "PashuMauli"
        assert "X-Request-ID" in response.headers


@pytest.mark.asyncio
async def test_ready_endpoint() -> None:
    """Test that GET /ready checks DB and Redis connectivity."""
    async with AsyncClient(
        transport=ASGITransport(app=app),  # type: ignore[arg-type]
        base_url="http://test",
    ) as client:
        response = await client.get("/ready")
        assert response.status_code in (200, 503)
        data = response.json()
        assert "database" in data
        assert "redis" in data
        if response.status_code == 200:
            assert data["status"] == "ready"
            assert data["database"] == "connected"
            assert data["redis"] == "connected"
        else:
            assert data["status"] == "degraded"


@pytest.mark.asyncio
async def test_all_15_tables_exist() -> None:
    """Test that all tables specified in DATABASE_SCHEMA.md exist in PostgreSQL."""
    engine = create_async_engine(settings.async_database_url)
    async with engine.connect() as conn:
        result = await conn.execute(
            text(
                "SELECT table_name FROM information_schema.tables "
                "WHERE table_schema = 'public';"
            )
        )
        existing_tables = {row[0] for row in result.fetchall()}
        missing = EXPECTED_TABLES - existing_tables
        assert not missing, f"Missing required migration tables: {missing}"
    await engine.dispose()


@pytest.mark.asyncio
async def test_spatial_indexes_exist() -> None:
    """Test that GiST spatial indexes exist on spatial tables."""
    expected_gist_indexes = {
        "ix_farmers_location",
        "ix_animals_location",
        "ix_health_cases_location",
        "ix_outbreaks_geometry",
        "ix_broadcasts_geometry",
    }
    engine = create_async_engine(settings.async_database_url)
    async with engine.connect() as conn:
        result = await conn.execute(
            text(
                "SELECT indexname FROM pg_indexes "
                "WHERE schemaname = 'public' AND indexdef LIKE '%USING gist%';"
            )
        )
        existing_gist = {row[0] for row in result.fetchall()}
        missing = expected_gist_indexes - existing_gist
        assert not missing, f"Missing GiST spatial indexes: {missing}"
    await engine.dispose()


@pytest.mark.asyncio
async def test_unique_constraints_and_indexes() -> None:
    """Test critical unique constraints for idempotency and entity identity."""
    engine = create_async_engine(settings.async_database_url)
    async with engine.connect() as conn:
        result = await conn.execute(
            text(
                "SELECT indexname FROM pg_indexes "
                "WHERE schemaname = 'public' AND indexdef LIKE '%UNIQUE%';"
            )
        )
        unique_indexes = {row[0] for row in result.fetchall()}
        assert any("users" in idx and "phone" in idx for idx in unique_indexes)
        assert any("animals" in idx and "ear_tag" in idx for idx in unique_indexes)
        assert any("health_cases" in idx and "client_id" in idx for idx in unique_indexes)
        assert any("lab_samples" in idx and "sample_code" in idx for idx in unique_indexes)
        assert any("sync_operations" in idx and "client_id" in idx for idx in unique_indexes)
    await engine.dispose()
