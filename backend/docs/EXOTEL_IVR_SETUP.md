# Exotel IVR Setup Guide — PashuMauli

This document details the configuration required in the Exotel Call Flow Builder to integrate with PashuMauli's synchronous Exotel Webhook Adapter (`GET /api/v1/ivr/exotel/passthru`).

---

## 1. Flow Architecture

Exotel Call Flow uses **Gather** applets to collect user DTMF inputs and **Passthru** applets to send those inputs synchronously to the PashuMauli backend.

```
CALL START
  ↓
IVR MENU — LANGUAGE
  ↓
PASSTHRU stage=language  (Make Passthru Async = OFF)
  ↓
GATHER — FARMER ID
  ↓
PASSTHRU stage=farmer_id (Make Passthru Async = OFF)
  ↓
GATHER — ANIMAL ID
  ↓
PASSTHRU stage=animal_id (Make Passthru Async = OFF)
  ↓
GATHER — SYMPTOM 1 (eating_problem)
  ↓
PASSTHRU stage=symptom_1 (Make Passthru Async = OFF)
  ↓
GATHER — SYMPTOM 2 (fever)
  ↓
PASSTHRU stage=symptom_2 (Make Passthru Async = OFF)
  ↓
GATHER — SYMPTOM 3 (respiratory_problem)
  ↓
PASSTHRU stage=symptom_3 (Make Passthru Async = OFF)
  ↓
GATHER — SYMPTOM 4 (digestive_problem)
  ↓
PASSTHRU stage=symptom_4 (Make Passthru Async = OFF)
  ↓
GATHER — SYMPTOM 5 (movement_or_visible_abnormality)
  ↓
PASSTHRU stage=symptom_5 (Make Passthru Async = OFF)
  ↓
GATHER — CONFIRMATION (1 = Create, 2 = Restart)
  ↓
PASSTHRU stage=confirmation (Make Passthru Async = OFF)
  ↓
SUCCESS → HANGUP
ERROR → Retry Branch
```

---

## 2. Critical Applet Settings

- **HTTP Method:** `GET`
- **Make Passthru Async:** `OFF` (Exotel must wait for the backend's HTTP 200 / non-200 decision to branch correctly).
- **URL Parameters:** Exotel automatically appends `CallSid`, `From` / `CallFrom`, `To`, `digits`, and `CurrentTime`.

---

## 3. Webhook URL Templates

Replace `<PUBLIC_DOMAIN>` with your HTTPS production domain or active Cloudflare Quick Tunnel URL.

| Stage | Exotel Passthru URL Template |
|---|---|
| **Language** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=language` |
| **Farmer ID** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=farmer_id` |
| **Animal ID** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=animal_id` |
| **Symptom 1** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=symptom_1` |
| **Symptom 2** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=symptom_2` |
| **Symptom 3** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=symptom_3` |
| **Symptom 4** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=symptom_4` |
| **Symptom 5** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=symptom_5` |
| **Confirmation** | `https://<PUBLIC_DOMAIN>/api/v1/ivr/exotel/passthru?stage=confirmation` |

> [!NOTE]
> If `EXOTEL_WEBHOOK_SHARED_SECRET` is set in `.env`, append `&secret=<YOUR_SHARED_SECRET>` to each URL template.

---

## 4. Standard Symptom Definitions

1. `symptom_1` (`eating_problem`): *"Is the animal eating less than usual or refusing food?"* (1 = Yes, 2 = No)
2. `symptom_2` (`fever`): *"Does the animal appear to have fever or feel unusually hot?"* (1 = Yes, 2 = No)
3. `symptom_3` (`respiratory_problem`): *"Is the animal having difficulty breathing or coughing?"* (1 = Yes, 2 = No)
4. `symptom_4` (`digestive_problem`): *"Does the animal have diarrhea, vomiting, or another digestive problem?"* (1 = Yes, 2 = No)
5. `symptom_5` (`movement_or_visible_abnormality`): *"Is the animal having difficulty walking or showing unusual swelling, injury, or other visible abnormality?"* (1 = Yes, 2 = No)

---

## 5. Security & Verification

- For production, configure `EXOTEL_WEBHOOK_SHARED_SECRET` in `.env` and configure the matching secret parameter or header in Exotel.
- The endpoint returns HTTP 200 on valid inputs/transitions and HTTP 400/403/404 on invalid inputs, causing Exotel to route to the error/retry applet branch.
