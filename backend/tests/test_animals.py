"""Phase 2 animals API tests."""
import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app

pytestmark = pytest.mark.asyncio


async def _register_and_login(client: AsyncClient, phone: str) -> str:
    await client.post(
        "/api/v1/auth/register",
        json={"name": "Vet", "phone": phone, "password": "vetpass123", "role": "FIELD_VET"},
    )
    resp = await client.post(
        "/api/v1/auth/login",
        json={"phone": phone, "password": "vetpass123"},
    )
    return resp.json()["access_token"]


async def _create_farmer(client: AsyncClient, token: str, phone: str = "07020000001") -> str:
    resp = await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Animal Owner", "phone": phone},
    )
    return resp.json()["id"]


@pytest_asyncio.fixture
async def client():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as ac:
        yield ac


@pytest_asyncio.fixture
async def auth_token(client: AsyncClient) -> str:
    return await _register_and_login(client, "+9902200001")


@pytest_asyncio.fixture
async def farmer_id(client: AsyncClient, auth_token: str) -> str:
    return await _create_farmer(client, auth_token)




# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

async def test_create_animal(client: AsyncClient, auth_token: str, farmer_id: str):
    resp = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "ear_tag_id": "TEST-001",
            "farmer_id": farmer_id,
            "species": "Cattle",
            "breed": "Gir",
            "sex": "Female",
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["ear_tag_id"] == "TEST-001"
    assert data["species"] == "Cattle"
    assert data["status"] == "ACTIVE"


async def test_duplicate_ear_tag_returns_409(client: AsyncClient, auth_token: str, farmer_id: str):
    payload = {
        "ear_tag_id": "TEST-DUP-001",
        "farmer_id": farmer_id,
        "species": "Buffalo",
    }
    r1 = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json=payload,
    )
    assert r1.status_code == 201
    r2 = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json=payload,
    )
    assert r2.status_code == 409
    assert r2.json()["error"]["code"] == "EAR_TAG_TAKEN"


async def test_create_animal_invalid_farmer(client: AsyncClient, auth_token: str):
    resp = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "ear_tag_id": "TEST-NOFARM-001",
            "farmer_id": "00000000-0000-0000-0000-000000000000",
            "species": "Cattle",
        },
    )
    assert resp.status_code == 404
    assert resp.json()["error"]["code"] == "FARMER_NOT_FOUND"


async def test_list_animals_filter_by_farmer(client: AsyncClient, auth_token: str, farmer_id: str):
    await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"ear_tag_id": "TEST-FILTER-001", "farmer_id": farmer_id, "species": "Goat"},
    )
    resp = await client.get(
        f"/api/v1/animals?farmer_id={farmer_id}",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    for item in data["items"]:
        assert item["farmer_id"] == farmer_id


async def test_get_animal(client: AsyncClient, auth_token: str, farmer_id: str):
    create = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"ear_tag_id": "TEST-GET-001", "farmer_id": farmer_id, "species": "Sheep"},
    )
    aid = create.json()["id"]
    resp = await client.get(
        f"/api/v1/animals/{aid}",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == aid


async def test_patch_animal_status(client: AsyncClient, auth_token: str, farmer_id: str):
    create = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"ear_tag_id": "TEST-PATCH-001", "farmer_id": farmer_id, "species": "Cattle"},
    )
    aid = create.json()["id"]
    resp = await client.patch(
        f"/api/v1/animals/{aid}",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"status": "SICK"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "SICK"


async def test_get_nonexistent_animal(client: AsyncClient, auth_token: str):
    resp = await client.get(
        "/api/v1/animals/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 404


async def test_animal_with_location(client: AsyncClient, auth_token: str, farmer_id: str):
    resp = await client.post(
        "/api/v1/animals",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "ear_tag_id": "TEST-LOC-001",
            "farmer_id": farmer_id,
            "species": "Buffalo",
            "location": {"longitude": 74.0, "latitude": 19.0},
        },
    )
    assert resp.status_code == 201
    assert resp.json()["location"]["longitude"] == pytest.approx(74.0, abs=0.001)
