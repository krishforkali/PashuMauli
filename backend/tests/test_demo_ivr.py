"""Tests for Phase 8 / Version-A Demo IVR state machine and webhooks."""
from typing import cast

import pytest
import pytest_asyncio
from httpx import ASGITransport, AsyncClient

from app.core.config import get_settings
from app.main import app

pytestmark = pytest.mark.asyncio
settings = get_settings()


@pytest_asyncio.fixture
async def client():
    # Enable DEMO_MODE for IVR tests
    settings.DEMO_MODE = True
    async with AsyncClient(
        transport=ASGITransport(app=app),  # type: ignore[arg-type]
        base_url="http://test",
    ) as ac:
        yield ac


async def test_demo_ivr_start_call(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/demo/ivr/call/start",
        json={"caller_phone": "+919876543210", "language": "mr"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert "call_id" in data
    assert data["current_step"] == "WELCOME"
    assert "PashuMauli" in data["prompt"]


async def test_demo_ivr_interactive_flow_and_case_creation(client: AsyncClient) -> None:
    """Test full step-by-step Gather -> Passthru IVR session culminating in case creation."""
    # 1. Start call
    start_resp = await client.post(
        "/api/v1/demo/ivr/call/start",
        json={"caller_phone": "+919876543210", "language": "mr"},
    )
    call_id = cast(str, start_resp.json()["call_id"])

    # 2. Step 1: Select Language Marathi (1)
    step1 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "1"},
    )
    assert step1.status_code == 200
    assert step1.json()["current_step"] == "LANGUAGE"

    # 3. Step 2: Farmer Phone / ID digits
    step2 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "9876543210#"},
    )
    assert step2.status_code == 200
    assert step2.json()["current_step"] == "FARMER_ID"

    # 4. Step 3: Animal Ear Tag digits
    step3 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "123456#"},
    )
    assert step3.status_code == 200
    assert step3.json()["current_step"] == "ANIMAL_ID"

    # 5. Symptom 1: Fever (Yes = 1)
    sym1 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "1"},
    )
    assert sym1.status_code == 200
    assert sym1.json()["current_step"] == "SYMPTOM_1"

    # 6. Symptom 2: Blisters (Yes = 1)
    sym2 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "1"},
    )
    assert sym2.status_code == 200
    assert sym2.json()["current_step"] == "SYMPTOM_2"

    # 7. Symptom 3: Milk Drop (No = 2)
    sym3 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "2"},
    )
    assert sym3.status_code == 200
    assert sym3.json()["current_step"] == "SYMPTOM_3"

    # 8. Symptom 4: Respiratory (No = 2)
    sym4 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "2"},
    )
    assert sym4.status_code == 200
    assert sym4.json()["current_step"] == "SYMPTOM_4"

    # 9. Symptom 5: Lameness (Yes = 1) -> triggers confirmation step prompt
    sym5 = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "1"},
    )
    assert sym5.status_code == 200
    assert sym5.json()["current_step"] == "SYMPTOM_5"

    # 10. Confirmation (1 = Confirm Case Creation)
    confirm = await client.post(
        "/api/v1/demo/ivr/call/step",
        json={"call_id": call_id, "digits": "1"},
    )
    assert confirm.status_code == 200
    res = confirm.json()
    assert res["case_created"] is True
    assert res["case"] is not None
    assert res["case"]["source"] == "IVR"
    assert len(res["case"]["symptoms"]) == 3  # 3 Yes symptoms reported


async def test_demo_ivr_single_request_incoming(client: AsyncClient) -> None:
    resp = await client.post(
        "/api/v1/demo/ivr/incoming",
        json={
            "caller_phone": "+919988776655",
            "language": "mr",
            "farmer_name": "Direct IVR Farmer",
            "animal_id": "EAR-TAG-IVR-001",
            "symptoms": "High fever, foot lesions",
            "latitude": 18.5204,
            "longitude": 73.8567,
        },
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["source"] == "IVR"
    assert "id" in data
