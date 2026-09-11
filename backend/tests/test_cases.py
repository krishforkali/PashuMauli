"""Phase 2 health cases API tests — includes idempotency and AI result stub."""
import uuid
from collections.abc import AsyncGenerator
from typing import cast

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.main import app
from tests.conftest import _sync_db

pytestmark = pytest.mark.asyncio


async def _register_and_login(client: AsyncClient, phone: str) -> str:
    await client.post(
        "/api/v1/auth/register",
        json={"name": "Case Vet", "phone": phone, "password": "casepass99", "role": "FIELD_VET"},
    )
    resp = await client.post(
        "/api/v1/auth/login",
        json={"phone": phone, "password": "casepass99"},
    )
    return cast(str, resp.json()["access_token"])


async def _create_farmer(client: AsyncClient, token: str, phone: str) -> str:
    resp = await client.post(
        "/api/v1/farmers",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Case Farmer", "phone": phone},
    )
    return cast(str, resp.json()["id"])


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    async with AsyncClient(
        transport=ASGITransport(app=app),  # type: ignore[arg-type]
        base_url="http://test",
    ) as ac:
        yield ac


@pytest_asyncio.fixture
async def auth_token(client: AsyncClient) -> str:
    return await _register_and_login(client, "+9903300001")


@pytest_asyncio.fixture
async def farmer_id(client: AsyncClient, auth_token: str) -> str:
    return await _create_farmer(client, auth_token, "07030000001")


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

async def test_create_case_basic(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    resp = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "farmer_id": farmer_id,
            "source": "DASHBOARD",
            "symptoms": ["fever", "lethargy"],
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["source"] == "DASHBOARD"
    assert data["risk_level"] == "UNKNOWN"
    assert data["status"] == "OPEN"
    assert "fever" in data["symptoms"]


async def test_create_case_idempotent_client_id(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    """AT-04 stub: same client_id submitted twice returns existing case (HTTP 200)."""
    cid = str(uuid.uuid4())
    payload = {
        "client_id": cid,
        "farmer_id": farmer_id,
        "source": "MOBILE",
        "symptoms": ["cough"],
    }
    r1 = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json=payload,
    )
    assert r1.status_code == 201

    r2 = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json=payload,
    )
    assert r2.status_code == 200  # ALREADY_APPLIED
    assert r1.json()["id"] == r2.json()["id"]  # same record returned


async def test_create_case_invalid_source(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    resp = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "INVALID_SOURCE", "symptoms": []},
    )
    assert resp.status_code == 422


async def test_list_cases(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "DASHBOARD", "symptoms": []},
    )
    resp = await client.get(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "items" in data
    assert data["total"] >= 1


async def test_list_cases_filter_by_source(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "MOBILE", "symptoms": ["fever"]},
    )
    resp = await client.get(
        "/api/v1/cases?source=MOBILE",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    for item in resp.json()["items"]:
        assert item["source"] == "MOBILE"


async def test_get_case(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    create = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "DASHBOARD", "symptoms": []},
    )
    cid = create.json()["id"]
    resp = await client.get(
        f"/api/v1/cases/{cid}",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 200
    assert resp.json()["id"] == cid


async def test_patch_case_status(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    create = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "DASHBOARD", "symptoms": []},
    )
    cid = create.json()["id"]
    resp = await client.patch(
        f"/api/v1/cases/{cid}",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"status": "IN_PROGRESS"},
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "IN_PROGRESS"


async def test_patch_case_invalid_status(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    create = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "DASHBOARD", "symptoms": []},
    )
    cid = create.json()["id"]
    resp = await client.patch(
        f"/api/v1/cases/{cid}",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"status": "INVALID_STATUS"},
    )
    assert resp.status_code == 422


async def test_attach_ai_result_stub(client: AsyncClient, auth_token: str, farmer_id: str) -> None:
    """Attaching AI result (Phase 2 stub) stores result and updates case.ai_model_version."""
    create = await client.post(
        "/api/v1/cases",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={"farmer_id": farmer_id, "source": "MOBILE", "symptoms": ["skin lesions"]},
    )
    cid = create.json()["id"]

    resp = await client.post(
        f"/api/v1/cases/{cid}/ai-result",
        headers={"Authorization": f"Bearer {auth_token}"},
        json={
            "model_name": "TestModel",
            "model_version": "v0.1-test",
            "input_type": "IMAGE",
            "predictions": {"FMD": 0.85, "BQ": 0.10},
            "top_prediction": "TestDisease",
            "confidence": 0.85,
            "inference_ms": 120.5,
        },
    )
    assert resp.status_code == 201
    result = resp.json()
    assert result["model_name"] == "TestModel"
    assert result["top_prediction"] == "TestDisease"
    assert result["confidence"] == pytest.approx(0.85, abs=0.01)

    # Verify case was updated
    case_resp = await client.get(
        f"/api/v1/cases/{cid}",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert case_resp.json()["ai_model_version"] == "v0.1-test"
    assert case_resp.json()["suspected_disease"] == "TestDisease"


async def test_get_nonexistent_case(client: AsyncClient, auth_token: str) -> None:
    resp = await client.get(
        "/api/v1/cases/00000000-0000-0000-0000-000000000000",
        headers={"Authorization": f"Bearer {auth_token}"},
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# AT-25 stub: Audit log for privileged actions
# ---------------------------------------------------------------------------


async def test_audit_log_on_login(client: AsyncClient, auth_token: str) -> None:
    """Verify an audit_log entry was created for the login that produced auth_token."""
    conn = _sync_db()
    try:
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM audit_logs WHERE action = 'USER_LOGIN'")
        count = cur.fetchone()[0]
        cur.close()
    finally:
        conn.close()
    assert count >= 1
