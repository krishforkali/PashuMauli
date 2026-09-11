"""Phase 2 farmers API tests."""
from collections.abc import AsyncGenerator
from typing import cast

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.asyncio

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _register_and_login(client: AsyncClient, phone: str, password: str = "testpass99") -> str:
    """Register a user and return a valid access token."""
    await client.post(
        "/api/v1/auth/register",
        json={"name": "Test User", "phone": phone, "password": password, "role": "FIELD_VET"},
    )
    resp = await client.post(
        "/api/v1/auth/login",
        json={"phone": phone, "password": password},
    )
    return cast(str, resp.json()["access_token"])


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(
        transport=ASGITransport(app=app),  # type: ignore[arg-type]
        base_url="http://test",
    ) as ac:
        yield ac


@pytest_asyncio.fixture
async def auth_token(client: AsyncClient) -> str:
    return await _register_and_login(client, "+9901100001")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

async def test_create_farmer(client: AsyncClient, auth_token: str) -> None:
    resp = await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"name": "Ram Kumar", "phone": "07000000001", "preferred_language": "hi"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Ram Kumar"
    assert "id" in data


async def test_create_farmer_with_location(client: AsyncClient, auth_token: str) -> None:
    resp = await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "name": "Sita Devi",
            "phone": "07000000002",
            "location": {"longitude": 73.8567, "latitude": 18.5204},
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["location"]["longitude"] == pytest.approx(73.8567, abs=0.001)


async def test_list_farmers_masked_phone(client: AsyncClient, auth_token: str) -> None:
    await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"name": "Phone Mask Test", "phone": "07009988776"},
    )
    resp = await client.get(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert "total" in data
    # Phone must be masked in list responses
    for item in data["items"]:
        if item.get("phone_masked"):
            assert "****" in item["phone_masked"]


async def test_get_farmer_full_phone(client: AsyncClient, auth_token: str) -> None:
    create_resp = await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"name": "Full Phone", "phone": "07099887766"},
    )
    fid = create_resp.json()["id"]
    resp = await client.get(
        f"/api/v1/farmers/{fid}",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    # Full phone visible in detail
    assert resp.json()["phone"] == "07099887766"


async def test_patch_farmer(client: AsyncClient, auth_token: str) -> None:
    create_resp = await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"name": "Original Name", "phone": "07011223344"},
    )
    fid = create_resp.json()["id"]
    resp = await client.patch(
        f"/api/v1/farmers/{fid}",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"name": "Updated Name"},
    )
    assert resp.status_code == 200
    assert resp.json()["name"] == "Updated Name"


async def test_get_nonexistent_farmer(client: AsyncClient, auth_token: str) -> None:
    resp = await client.get(
        "/api/v1/farmers/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 404


async def test_unauthenticated_farmer_request(client: AsyncClient) -> None:
    resp = await client.get("/api/v1/farmers")
    assert resp.status_code == 403  # HTTPBearer returns 403 when no token


async def test_farmer_pagination(client: AsyncClient, auth_token: str) -> None:
    resp = await client.get(
        "/api/v1/farmers?page=1&page_size=5",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["page"] == 1
    assert data["page_size"] == 5
