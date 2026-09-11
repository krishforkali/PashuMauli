# PashuMauli — Implementation Plan

**Based on:** MASTER_SPEC.md §22, ARCHITECTURE.md, docs/ (all files)  
**Rule:** Do not begin a later phase while the preceding phase's acceptance criteria are failing (MASTER_SPEC §22).  
**Ambiguities:** Logged below and in `IMPLEMENTATION_NOTES.md` when encountered.

---

## 0. Dependency Graph

```
Phase 0  ──────────────────────────────────────────┐
  Spec review + plan (this document)                │
Phase 1  ──────────────────────────────────────────▼
  Infra + DB foundation                             │
  Docker Compose: PostgreSQL/PostGIS, Redis         │
  Alembic init, core schema migrations              │
Phase 2  ──────────────────────────────────────────▼
  Auth, users, farmers, animals (backend)           │
  JWT, RBAC, /auth, /farmers, /animals APIs         │
Phase 3  ──────────────────────────────────────────▼
  Mobile foundation                                 │
  Flutter project, SQLite, nav, lang, auth screens  │
Phase 4  ──────────────────────────────────────────▼
  Sync engine (backend + mobile)                    │
  /sync, sync_operations table, idempotency          │
Phase 5  ──────────────────────────────────────────▼
  AI/risk/advisory (backend + mobile)               │
  TFLite model adapter, risk engine, advisory rules │
Phase 6  ──────────────────────────────────────────▼
  Dashboard + GIS                                   │
  Next.js project, Leaflet map, REST views          │
Phase 7  ──────────────────────────────────────────▼
  WebSockets                                        │
  /ws/alerts, event emission, dashboard reconnect   │
Phase 8  ──────────────────────────────────────────▼
  IVR                                               │
  Provider adapters, webhook, STT, case creation    │
Phase 9  ──────────────────────────────────────────▼
  Emergency broadcast                               │
  PostGIS targeting, Redis queue, worker fan-out    │
Phase 10 ──────────────────────────────────────────▼
  Lab / vaccination / analytics                     │
  /lab-samples, /vaccinations, coverage, analytics  │
Phase 11 ──────────────────────────────────────────▼
  Integration hardening                             │
  Rate limiting, audit, provider health, security   │
Phase 12 ──────────────────────────────────────────▼
  Tests, demo, release                              │
  AT-01 → AT-25, demo scripts, secret scan          │
```

**Strict dependency edges:**
- Phase 2 requires Phase 1 migrations complete.
- Phase 3 requires Phase 2 auth API endpoints tested.
- Phase 4 requires Phase 2 (backend) + Phase 3 (mobile) both complete.
- Phase 5 requires Phase 2 health_cases/ai_results tables exist.
- Phase 6 requires Phase 2 REST APIs complete (reads data).
- Phase 7 requires Phase 2 + Phase 6 (dashboard exists to receive events).
- Phase 8 requires Phase 2 (health case pipeline), Phase 7 (WS emission).
- Phase 9 requires Phase 2 (users/farmers GIS), Phase 7 (broadcast events), Phase 8 (outbound voice adapter).
- Phase 10 requires Phase 2 (animals, cases, users tables).
- Phase 11 requires all preceding phases stable.
- Phase 12 requires all acceptance tests listed per phase passing.

---

## Phase 0 — Specification Review and Plan

**Goal:** Understand the full system before writing code. This document is the deliverable.

### Tasks
- [x] Read MASTER_SPEC.md, ARCHITECTURE.md, all docs/.
- [x] Identify all entities, APIs, events, integrations.
- [x] Produce IMPLEMENTATION_PLAN.md with dependency order.
- [ ] Create IMPLEMENTATION_NOTES.md for any ambiguities discovered.
- [ ] Confirm `.env.example` covers all required environment variables.
- [ ] Verify Docker Compose configuration is present or scaffold it.
- [ ] Confirm repository directory structure: `backend/`, `mobile/`, `dashboard/`, `scripts/`, `docs/`.

### Gate 0
- This plan document exists and is internally consistent.
- No feature implementation has begun.
- Ambiguities documented, not silently resolved.

---

## Phase 1 — Database, Migrations, Backend Foundation

**Goal:** Authoritative data layer ready; no application logic yet.

### 1A — Infra scaffolding
- `docker-compose.yml`: PostgreSQL 15+ with PostGIS extension, Redis.
- `.env.example`: DATABASE_URL, REDIS_URL, SECRET_KEY, JWT_ALGORITHM, JWT_EXPIRY.
- `backend/` Python project: FastAPI, SQLAlchemy, Alembic, psycopg2/asyncpg, Redis client.
- `pyproject.toml` / `requirements.txt` with pinned dependencies.
- `backend/app/main.py`: bare FastAPI app, `/health` and `/ready` stubs.
- `backend/app/core/config.py`: typed settings from environment.
- Structured logging with request IDs.

### 1B — Database migration sequence (Alembic)

All migrations are additive. Order is strictly enforced by Alembic revision chain.

| # | Migration | Tables created | Indexes | Notes |
|---|-----------|---------------|---------|-------|
| 001 | enable_postgis | — | — | `CREATE EXTENSION IF NOT EXISTS postgis` |
| 002 | create_users | users | users.phone (UNIQUE), users.role | UUID PK, timestamptz |
| 003 | create_gis_references | districts, blocks, villages | geometry GiST each | Schema-only; data loaded separately |
| 004 | create_farmers | farmers | farmers.location GiST | FK → users(id) nullable |
| 005 | create_animals | animals | animals.ear_tag_id (UNIQUE), animals.location GiST | FK → farmers(id) |
| 006 | create_health_cases | health_cases | health_cases.status, .created_at, .location GiST, .client_id UNIQUE | FK → animals, farmers, users nullable |
| 007 | create_ai_results | ai_results | ai_results.case_id | FK → health_cases(id) |
| 008 | create_vaccinations | vaccinations | vaccinations.animal_id | FK → animals(id), users(id) nullable |
| 009 | create_lab_samples | lab_samples | lab_samples.sample_code UNIQUE | FK → health_cases(id), users(id) nullable |
| 010 | create_outbreaks | outbreaks | outbreaks.geometry GiST | geometry GEOGRAPHY(MultiPolygon,4326) |
| 011 | create_notifications | notifications | notifications.user_id | FK → users(id) |
| 012 | create_broadcasts | broadcasts | — | FK → users(id); geometry GEOGRAPHY |
| 013 | create_broadcast_deliveries | broadcast_deliveries | (broadcast_id,status); UNIQUE(broadcast_id,user_id,channel) | FK → broadcasts, users |
| 014 | create_sync_operations | sync_operations | (status,created_at) | client_id UNIQUE |
| 015 | create_audit_logs | audit_logs | audit_logs.created_at | FK → users nullable |

**Migration rules:** Never modify existing migration files. New column/index = new migration. Always `alembic upgrade head` in CI.

### 1C — Backend project skeleton
- `backend/app/db/base.py`: SQLAlchemy declarative base, async session factory.
- `backend/app/models/`: one file per entity matching schema above.
- `backend/app/api/v1/router.py`: include sub-routers (stubs for now).
- `backend/app/core/security.py`: password hashing (bcrypt), JWT encode/decode.
- `backend/app/core/middleware.py`: request ID injection, structured logging.
- `backend/app/integrations/`: empty packages for SMS, voice, push, storage, STT, TTS.

### Gate 1
- `alembic upgrade head` runs cleanly against a fresh PostgreSQL/PostGIS container.
- `GET /health` returns 200.
- `GET /ready` checks DB + Redis connectivity; returns 200 or 503.
- All 15 migrations apply in order; `alembic downgrade base` also succeeds.
- `pytest backend/tests/test_migrations.py` passes.
- No application secrets committed.

---

## Phase 2 — Auth, Users, Farmers, Animals

**Goal:** Core identity and livestock data are accessible over authenticated REST APIs.

### 2A — Authentication and RBAC
- `POST /api/v1/auth/register` — create user with phone, password, role (role controlled/validated by backend).
- `POST /api/v1/auth/login` — return JWT access token + refresh token.
- `POST /api/v1/auth/refresh` — rotate access token.
- RBAC roles from SECURITY.md: `FARMER`, `FIELD_VET`, `DISTRICT_OFFICER`, `STATE_ADMIN`, `LAB_USER`, `SYSTEM_ADMIN`.
- Role-based dependency injected on each protected route.
- Secure password hashing (bcrypt).
- JWT secrets from environment only.
- Rate limiting on auth endpoints.
- Audit log entry for login, registration of privileged roles.

### 2B — Farmers API
- `POST /api/v1/farmers` — create farmer; emit `FARMER_REGISTERED` (stub WS for Phase 7).
- `GET /api/v1/farmers` — list with pagination, role-scoped.
- `GET /api/v1/farmers/{id}` — single farmer.
- `PATCH /api/v1/farmers/{id}` — update farmer.
- GPS location stored as GEOGRAPHY(Point,4326).
- Phone minimized in list responses (per SECURITY.md privacy rule).

### 2C — Animals API
- `POST /api/v1/animals` — create animal with ear_tag_id, farmer_id, species, breed, sex, date_of_birth, location.
- `GET /api/v1/animals` — list, filter by farmer_id, species, status.
- `GET /api/v1/animals/{id}` — single animal.
- `PATCH /api/v1/animals/{id}` — update.
- ear_tag_id is unique; duplicate should return 409.

### 2D — Health cases API (core, no AI yet)
- `POST /api/v1/cases` — accept `client_id` for idempotency; source enum: MOBILE/IVR/DASHBOARD/IMPORT.
- `GET /api/v1/cases` — list with filters: disease, risk_level, source, status, date range.
- `GET /api/v1/cases/{id}` — single case.
- `PATCH /api/v1/cases/{id}` — update status, assignment.
- `POST /api/v1/cases/{id}/ai-result` — attach AI result (stub; full logic Phase 5).
- Idempotency on `client_id`: return existing record with `ALREADY_APPLIED` if resubmitted.

### 2E — Input validation and error envelope
- All requests validated via Pydantic v2 models.
- Error envelope: `{"error":{"code":"...","message":"...","details":{}}}`.
- 422 for validation, 401 for auth, 403 for RBAC, 404 for not found, 409 for conflict.

### Gate 2
- AT-01: Register farmer via API → farmer persists in DB.
- AT-18: Farmer role cannot access emergency broadcast endpoint (403).
- AT-25: Privileged actions produce audit log entries.
- Auth tests: expired token rejected, wrong role rejected.
- RBAC matrix unit tested for all six roles.
- `pytest backend/tests/test_auth.py backend/tests/test_farmers.py backend/tests/test_animals.py backend/tests/test_cases.py` passes.
- Lint + type checks clean.

---

## Phase 3 — Mobile Foundation (Flutter + SQLite)

**Goal:** Flutter app navigates all screens, stores data locally, works fully offline.

### 3A — Flutter project scaffold
- `mobile/` Flutter project: Dart, null-safety, `flutter_riverpod` or `provider` for state.
- `pubspec.yaml`: `sqflite`, `path_provider`, `http`, `flutter_secure_storage`, `geolocator`, `image_picker`, `tflite_flutter`.
- Localization: `flutter_localizations` for English, Hindi, Marathi (l10n ARB files).
- Role-aware navigation using GoRouter or Navigator 2.0.

### 3B — SQLite schema (mobile)
Local tables mirroring server entities (subset for offline use):
- `local_users` — session metadata.
- `local_farmers` — id (UUID), synced flag.
- `local_animals` — id (UUID), farmer_id, ear_tag_id, species, status, synced.
- `local_health_cases` — id (UUID), client_id, animal_id, symptoms JSON, risk_level, status, synced.
- `local_vaccinations` — id (UUID), animal_id, synced.
- `sync_queue` — client_id, entity_type, entity_id, operation, payload JSON, status, attempt_count, created_at.
- `model_metadata` — model_name, model_version, file_path, hash.
- `pending_media` — local_path, entity_type, entity_id, status.

All writes committed in SQLite transaction before UI reports success (OFFLINE_SYNC.md rule).

### 3C — Screen implementation order
Screens must be implemented in this order to respect navigation dependencies:

1. **Splash** — load local config, session, model metadata.
2. **Language** — English/Hindi/Marathi selection; persisted locally.
3. **Login/Registration** — phone + credentials; JWT stored in `flutter_secure_storage`.
4. **Home** — quick actions (Register Farmer, Add Animal, Report Case, AI Scan, Offline Queue, Notifications); OFFLINE/ONLINE badge.
5. **Farmer profile** — identity, location, phone, animal list, cases.
6. **Animal list** — search by ear-tag/name, filter by status.
7. **Add animal** — ear-tag, species, breed, sex, age/DOB, GPS location.
8. **Animal profile** — health history, vaccinations, cases, photos.
9. **Vaccination history** — list per animal.
10. **Report symptoms** — animal selector, symptom checklist, notes, GPS, photo, submit → SQLite first.
11. **AI scan** — camera, capture/retry, offline inference indicator, model status.
12. **AI result** — prediction, confidence, risk, explanation, escalation prompt; no "confirmed" language.
13. **Advisory** — localized knowledge-base-backed actions, veterinary escalation link.
14. **Offline queue** — pending/synced/failed records, retry button.
15. **Sync status** — connectivity state, last sync timestamp, pending count, last error.
16. **Notifications** — emergency/case/outbreak notifications list.
17. **Settings** — language, permissions, account, model version, diagnostics.

### 3D — Offline-first UX rules
- Clearly show OFFLINE / ONLINE state.
- Never block field work because server is unreachable.
- Show sync failures plainly with retry option.
- Accessible buttons with large touch targets.

### Gate 3
- AT-02: Network off → register farmer → restart app → record remains.
- AT-03: Network off → create case → PENDING status in queue.
- AT-21: Pending ops survive app restart.
- All 17 screens render without crash.
- `flutter analyze` clean; `flutter test` passes widget and repository tests.
- SQLite write-before-UI-success verified by unit test.

---

## Phase 4 — Sync Engine

**Goal:** Offline operations reliably reach the server; duplicates suppressed; failures retry.

### 4A — Backend sync endpoints
- `POST /api/v1/sync` — accept batch of operations; validate auth; process each; return per-operation result: `APPLIED`, `ALREADY_APPLIED`, `REJECTED`, `RETRY`.
- `GET /api/v1/sync/status` — return pending/failed operation counts for current user.
- `POST /api/v1/sync/ack` — client confirms it received results.
- Server uses `client_id` (UUID from device) for idempotency on all entity creates.
- `sync_operations` table records every operation processed.

### 4B — Mobile sync manager
- `SyncManager` service: detect network change → acquire lock → read PENDING from `sync_queue` in created_at order → batch (bounded size) → POST /sync → parse per-operation results → local transaction to mark SYNCED/FAILED.
- Exponential backoff for RETRY results; bounded retries.
- Failed ops remain PENDING for next sync cycle.
- Emit local notification on successful sync.
- Release lock on success or failure.

### 4C — Media sync
- On connectivity: check `pending_media` for QUEUED items → upload to S3 via backend signed URL or proxy → mark STORED → server acknowledges → mark ACKNOWLEDGED.
- Never delete local original until ACKNOWLEDGED.
- Local file path stable across app restarts (use `path_provider` documents dir).

### 4D — Conflict policy (from OFFLINE_SYNC.md)
- Immutable historical reports never silently overwritten.
- Server-generated authoritative statuses override local status after sync.
- Editable profile fields: last-write/version conflict visible to user.

### Gate 4
- AT-04: Same client_id submitted twice → exactly one canonical record in DB.
- AT-05: Force sync failure → restore network → auto-retry → success acknowledged.
- AT-21: Restart after offline writes → all pending ops remain.
- Integration test: mobile creates farmer + case offline → sync → DB has correct single records.
- `pytest backend/tests/test_sync.py` passes (idempotency, batch processing, per-op results).
- Flutter sync queue unit tests pass.

---

## Phase 5 — AI / Risk / Advisory

**Goal:** On-device TFLite inference produces a risk-scored, advisory-backed case result.

### 5A — Mobile TFLite adapter
- `MLModelAdapter` interface: `load(modelPath)`, `infer(imageBytes)` → `MLResult{modelName, modelVersion, labels, confidences, inferenceMs}`.
- Concrete `TFLiteAdapter` using `tflite_flutter`.
- Model file bundled as asset or downloaded and stored locally (path in `model_metadata`).
- Model version recorded with each result.
- Model replaceable without changing business layer (adapter contract).

### 5B — Backend risk engine
- `RiskEngine.calculate(diseasePrediction, confidence, symptoms, outbreakContext, animalContext)` → `RiskResult{score, level, reasons, escalationRecommended}`.
- Inputs: disease candidate, confidence (0-1), symptom checklist, severity, geographic outbreak context (from outbreaks table), recent case density.
- Outputs: score 0–100, level `LOW/MEDIUM/HIGH/CRITICAL`, reasons list, escalation recommendation.
- Used by both mobile sync case creation and IVR case creation (same engine, MASTER_SPEC §10).
- Unit-testable with no external I/O.

### 5C — Advisory engine
- Structured veterinary knowledge base / rule set (approved content only).
- Advisory lookup by disease candidate + risk level → localized advisory text.
- If LLM translation/summarization is used, it may only summarize approved content; it must not generate treatment/medication instructions (AI_SPEC.md rule).
- `advisory_version` recorded on health_case.

### 5D — Low-confidence handling
- Confidence below configured threshold:
  - Do not present a definitive disease name.
  - Request more information / photo.
  - Recommend veterinary review.
- This logic is enforced in the mobile AI result screen and the backend case API.

### 5E — `POST /api/v1/cases/{id}/ai-result` (complete)
- Accept: model_name, model_version, input_type, predictions JSONB, top_prediction, confidence, inference_ms.
- Backend stores in `ai_results`.
- Trigger risk engine; update `health_case.risk_score`, `risk_level`, `ai_model_version`.
- Emit `AI_RESULT_AVAILABLE` WebSocket event (stub fires; WS live in Phase 7).

### Gate 5
- AT-07: Run supported image → prediction, confidence, model version, risk displayed.
- AT-08: Low-confidence → no "confirmed" label → veterinary review recommended.
- Unit tests: risk engine with known inputs → expected level/score.
- Advisory lookup returns knowledge-base content, not hallucinated text.
- `flutter test` TFLite adapter tests pass (mock inference).
- `pytest backend/tests/test_risk_engine.py backend/tests/test_advisory.py` pass.

---

## Phase 6 — Dashboard / GIS

**Goal:** Command center displays all data; Leaflet map renders cases and outbreaks.

### 6A — Dashboard project scaffold
- `dashboard/` Next.js + TypeScript project.
- Dependencies: `leaflet`, `react-leaflet`, `@types/leaflet`, `socket.io-client` or native WebSocket, `swr` or `react-query` for data fetching.
- `next.config.js`: proxy `/api/v1/` to backend (dev mode).
- Authentication: JWT stored in `httpOnly` cookie or secure storage; never exposed to provider.

### 6B — Screen implementation order
1. **Login** — JWT auth against backend `/auth/login`.
2. **Overview** — top metrics: total farmers, animals, active cases, high-risk cases, active outbreaks, vaccination coverage.
3. **Live map** — Leaflet + OSM tiles; markers, clusters, risk layers; district/block/village boundaries (when data available); case detail drawer; target drawing tools.
4. **Disease cases** — list with filters: disease, risk, district, source, status, date. Case detail view: animal, farmer, symptoms, AI result, timeline, assignments, lab status.
5. **Farmers** — directory: search, filters, profile drawer.
6. **Animals** — directory: search, filters.
7. **Outbreaks** — active clusters, timeline, case count, affected geography, response actions.
8. **Case details** — full detail page.
9. **Veterinary assignments** — assignment list and management.
10. **Laboratory** — samples, status, results, referral history.
11. **Vaccination** — coverage and records.
12. **Vaccine inventory** — display only.
13. **Analytics** — cases by time/geography/disease/species; vaccination coverage; response metrics.
14. **Alert center** — live alerts and acknowledgement.
15. **Emergency broadcast** — complete form (Phase 9 wires backend).
16. **Broadcast history** — list of past broadcasts and delivery status.
17. **User management** — list users, change roles (SYSTEM_ADMIN only).
18. **System status** — API, DB, Redis, WebSocket, telephony, SMS, storage provider health.

### 6C — GIS functions
- Farmer/animal/case point markers.
- District/block/village boundary overlays (when available).
- Radius selection tool.
- Polygon drawing tool.
- Case clustering (e.g., `leaflet.markercluster`).
- Outbreak visualization.
- `POST /api/v1/map/target-preview` — server-side recipient count (PostGIS); dashboard never calculates recipient list client-side.
- `GET /api/v1/map/cases` — returns GeoJSON of cases for map.
- `GET /api/v1/outbreaks` — active outbreaks.
- `GET /api/v1/outbreaks/heatmap` — density data.

### 6D — GIS backend
- PostGIS `ST_DWithin` for radius queries.
- PostGIS `ST_Within` / `ST_Intersects` for polygon/district queries.
- GeoJSON responses for map endpoints.
- Outbreak detection: configurable case-density threshold triggers `outbreaks` record.

### Gate 6
- AT-10: Cases at known test coordinates → map renders markers → server-side radius query returns correct results.
- AT-11: Clustered test cases → outbreak detection produces expected cluster.
- AT-14: Test radius/polygon → server-side recipient count computed correctly.
- Dashboard build (`next build`) succeeds with no TypeScript errors.
- Leaflet map renders in browser; markers appear; clustering works.
- `pytest backend/tests/test_gis.py` passes spatial queries.

---

## Phase 7 — WebSockets

**Goal:** Dashboard receives live events; reconnects automatically; never relies on WS as data store.

### 7A — Backend WebSocket endpoint
- `GET /ws/alerts` — authenticated WebSocket connection (token in header or query param).
- Connection registry: active connections stored in Redis (for multi-process readiness) or in-process dict (single process acceptable for MVP).
- Event publisher: `EventBus.emit(event_name, data)` → fan out to all connected dashboard clients.
- Events use versioned envelope: `{event, event_version, event_id, timestamp, data}`.
- `event_id` is UUID; clients deduplicate by tracking seen IDs.

### 7B — Events to implement (from WEBSOCKET_EVENTS.md)

| Event | Emitted when | Data |
|-------|-------------|------|
| `FARMER_REGISTERED` | POST /farmers succeeds | farmer_id, name, village_id, location summary |
| `ANIMAL_REGISTERED` | POST /animals succeeds | animal_id, ear_tag_id, farmer_id |
| `HEALTH_CASE_CREATED` | POST /cases succeeds | case_id, source, animal_id, disease, risk_level, location |
| `AI_RESULT_AVAILABLE` | POST /cases/{id}/ai-result succeeds | case_id, model_version, top_prediction, confidence, risk_level |
| `OUTBREAK_DETECTED` | Outbreak engine triggers | outbreak_id, disease, risk_level, case_count, geometry ref |
| `LAB_RESULT_UPDATED` | PATCH /lab-samples/{id} result set | sample_id, case_id, status, result summary |
| `VACCINATION_UPDATED` | POST /vaccinations succeeds | animal_id, vaccine, next_due_at |
| `BROADCAST_CREATED` | POST /emergency/broadcast succeeds | broadcast_id, event_type, recipient_count, channels |
| `BROADCAST_DELIVERY_UPDATED` | Worker updates delivery status | broadcast_id, delivery counts/status |
| `ALERT_CREATED` | System generates alert | alert_id, severity, title, reference_type, reference_id |

### 7C — Dashboard WebSocket client
- Auto-connect on mount; reconnect with exponential backoff on disconnect.
- Show connection state indicator (Connected / Reconnecting / Disconnected).
- After reconnect: fetch authoritative state via REST (do not rely on missed WS events).
- Ignore duplicate event_ids.
- New events: non-blocking toast/alert; update relevant views without page reload.
- Critical alerts may play sound if enabled.

### Gate 7
- AT-06: Create farmer/case from physical phone → dashboard updates without browser refresh.
- AT-20: Stop/restart backend WS → dashboard reconnects → refreshes authoritative state.
- WS unit test: emit event → client receives exactly once.
- Duplicate event_id → client ignores second occurrence.
- `pytest backend/tests/test_websocket.py` passes.
- Dashboard WS integration test passes.

---

## Phase 8 — IVR

**Goal:** Inbound call → structured case in DB → WebSocket event → dashboard updates.

### 8A — Provider abstraction
`TelephonyProvider` interface (IVR_SPEC.md):

```
create_inbound_response(state, prompt, options) -> str  # provider XML/JSON
start_outbound_call(to, message, callback_url) -> CallResult
get_call_status(call_id) -> CallStatus
validate_webhook(request) -> bool  # signature check
terminate_call(call_id) -> None    # where supported
```

- `ExotelAdapter`: implements for Exotel API.
- `TwilioAdapter`: implements for Twilio API.
- `MockTelephonyProvider`: implements for tests/demo; no real calls.
- Selection via `TELEPHONY_PROVIDER` environment variable.

### 8B — IVR state machine (backend)
States from IVR_SPEC.md:
`WELCOME → LANGUAGE → LOCATION → ANIMAL_TYPE → SYMPTOMS → RECORD/CONFIRM → PROCESSING → CASE_CREATED → CONFIRMATION → END`

- Call session stored in Redis (call_id → state + accumulated data).
- Each state transition: validate/reprompt on unrecognized input.
- Location: use caller's registered profile location if reliable; otherwise ask for district/village; never invent a precise location.

### 8C — IVR webhooks
- `POST /api/v1/ivr/incoming` — new inbound call; validate provider signature; create session; return WELCOME prompt.
- `POST /api/v1/ivr/input` — DTMF/speech input for current state; advance state machine; return next prompt.
- `POST /api/v1/ivr/recording` — audio upload; queue STT job.
- `POST /api/v1/ivr/status` — call status callback (completed, failed).
- All webhooks: signature validation (`validate_webhook`) + replay protection (nonce/timestamp check).

### 8D — Speech pipeline
`Audio → preprocessing → SpeechToTextProvider → language-aware symptom extraction → structured case`

- `SpeechToTextProvider` interface: `transcribe(audio_bytes, language)` → `TranscriptResult`.
- Whisper-compatible adapter (local or API).
- Symptom extraction: rule-based or keyword-matching on approved symptom vocabulary; not free-form generation.
- Structured case payload fed to same risk engine as mobile (MASTER_SPEC §10).

### 8E — Case creation from IVR
- Same `POST /cases` pipeline as mobile, with `source=IVR`.
- `HEALTH_CASE_CREATED` event emitted → dashboard receives.
- Audit log entry with call_id, caller identifier if known.
- Store only audio required by retention policy (per IVR_SPEC.md).

### 8F — TTS for IVR prompts
- `TextToSpeechProvider` interface: `synthesize(text, language)` → audio.
- Candidate: Amazon Polly or provider-native TTS.
- Must support Hindi/Marathi demo voice path after validation.

### Gate 8
- AT-12: Invoke mock webhook + test transcript → one health case in DB → one dashboard WS event.
- AT-13: Replay same callback → no duplicate case (idempotency via call session key).
- Webhook signature validation test: tampered signature rejected.
- STT adapter unit test with mock audio.
- `pytest backend/tests/test_ivr.py` passes.
- IVR session state machine unit tests pass.

---

## Phase 9 — Emergency Broadcast

**Goal:** Authorized broadcast triggers PostGIS-targeted fan-out via Redis workers; dashboard tracks delivery.

### 9A — Backend broadcast API
- `POST /api/v1/emergency/broadcast` — DISTRICT_OFFICER / STATE_ADMIN / SYSTEM_ADMIN only; validate role → audit → PostGIS recipient query → create `broadcasts` record → enqueue Redis jobs → return `{broadcast_id, status: "QUEUED", recipient_count}` quickly (async fan-out).
- `POST /api/v1/emergency/{id}/cancel` — cancel before dispatch where possible.
- `GET /api/v1/emergency/broadcasts` — list broadcasts.
- `GET /api/v1/emergency/broadcasts/{id}` — detail.
- `GET /api/v1/emergency/broadcasts/{id}/deliveries` — per-delivery status.
- `POST /api/v1/map/target-preview` — server-side recipient count preview (no PII returned to client).

### 9B — Geographic targeting (PostGIS)
Target types: district, block, radius, polygon (from EMERGENCY_BROADCAST.md).
- `ST_Within` / `ST_Intersects` farmer.location against target geometry.
- Only active, opted-in/authorized recipients.
- Duplicate suppression across channels.
- Target geometry validated server-side; client-provided recipient list never trusted.

### 9C — Redis queue and workers
- One job per recipient/channel combination.
- Job payload: broadcast_id, user_id, channel, message_variant, language.
- Worker picks up job → calls provider adapter → records `broadcast_deliveries` row.
- Status flow: `QUEUED → SENDING → SENT` (on API acceptance) / `DELIVERED` (on delivery callback) / `FAILED` / `CANCELLED`.
- Retry: transient failures with bounded exponential backoff; permanent failures stop retrying.
- Never report `DELIVERED` solely because API accepted the send request.

### 9D — Notification service and provider adapters
`NotificationService` dispatches to:
- `SMSProvider` → `MSG91Adapter` / `MockSMSProvider`.
- `PushProvider` → `FCMAdapter` / `MockPushProvider`.
- `VoiceProvider` → `ExotelAdapter` / `TwilioAdapter` / `MockVoiceProvider`.
- Optional `WhatsAppProvider` — Phase 2 feature; not MVP-required.

Each adapter: interface implemented, config from environment, timeout, retry policy, idempotency where supported, structured error handling, health status, mock for tests.

### 9E — Message localization
- Messages stored by language variant.
- If user's preferred language has no approved message: use approved fallback or exclude per policy.
- Do not machine-generate emergency instructions without review.
- Event types: FLOOD_WARNING, DISEASE_OUTBREAK, EXTREME_WEATHER, LIVESTOCK_MOVEMENT_RESTRICTION, VACCINATION_CAMPAIGN, CUSTOM_AUTHORIZED_ALERT.

### 9F — WebSocket broadcast events
- `BROADCAST_CREATED` → emitted when broadcast record created.
- `BROADCAST_DELIVERY_UPDATED` → emitted by worker on batch of delivery status updates.

### 9G — Audit
- Audit log entry before dispatch: actor, role, event_type, target geometry, channels, recipient_count, timestamp.
- Audit log entry for cancellation.

### Gate 9
- AT-14: Test radius/polygon → server-side recipient count correct.
- AT-15: Confirm broadcast → Redis jobs created → status moves QUEUED → SENDING → SENT/FAILED.
- AT-16: Users inside/outside polygon → only inside users targeted.
- AT-17: Provider mock accepts but not delivered → status is SENT, not DELIVERED.
- AT-18: Farmer role → 403 on broadcast creation → audit event recorded.
- AT-24: Provider timeout → bounded retry → FAILED status → dashboard shows error.
- AT-25: Broadcast audit event contains actor, action, timestamp, target.
- `pytest backend/tests/test_broadcast.py backend/tests/test_notifications.py` pass.

---

## Phase 10 — Lab / Vaccination / Analytics

**Goal:** Lab sample lifecycle and vaccination records complete; analytics views functional.

### 10A — Lab samples API
- `POST /api/v1/lab-samples` — create with case_id, sample_type, sample_code; status = COLLECTED.
- `GET /api/v1/lab-samples` — list, filter by status, case_id, lab_id.
- `GET /api/v1/lab-samples/{id}` — detail.
- `PATCH /api/v1/lab-samples/{id}` — update status; set result, result_at; emit `LAB_RESULT_UPDATED` WS event.
- LAB_USER role required for lab status updates.

### 10B — Vaccination API
- `POST /api/v1/vaccinations` — record vaccination for animal; FIELD_VET or higher.
- `GET /api/v1/vaccinations` — list, filter by animal_id, vaccine, date range.
- `GET /api/v1/vaccinations/coverage` — coverage aggregation by district/block/species/vaccine.
- Emit `VACCINATION_UPDATED` WS event on create.

### 10C — Analytics (backend aggregations)
- Cases by time period, geography, disease, species.
- Vaccination coverage by district/block.
- Response metrics (time from case to assignment, to resolution).
- Read-only aggregation queries; no new entities.

### 10D — Dashboard lab/vaccination/analytics screens
- Laboratory screen: samples list, status, results, referral history.
- Vaccination screen: coverage map + records.
- Vaccine inventory screen: display only.
- Analytics screen: charts for cases by time/geography/disease/species, vaccination coverage, response metrics.

### Gate 10
- AT-09: Create animal + vaccination + case records → chronological profile displayed.
- Lab sample create → update result → `LAB_RESULT_UPDATED` event → dashboard updates.
- Vaccination coverage endpoint returns correct aggregates for test data.
- `pytest backend/tests/test_lab.py backend/tests/test_vaccination.py backend/tests/test_analytics.py` pass.

---

## Phase 11 — Integration Hardening

**Goal:** Security, observability, provider health, and error handling are production-grade.

### 11A — Security hardening
- CORS allowlist from environment.
- Request size limits on all endpoints.
- Rate limiting: auth endpoints (strict), API endpoints (configurable).
- Webhook replay protection: nonce + timestamp window check.
- Input validation on all endpoints.
- Audit log completeness: every privileged action recorded.
- Secret scan: confirm no secrets in codebase or build output.
- Mobile: no provider secrets bundled; JWT in `flutter_secure_storage`; minimize PII in SQLite.
- Dashboard: no secrets in JS bundle; JWT in httpOnly cookie or secure storage.

### 11B — Observability
- Backend: structured JSON logs with request_id on every log line; log level from environment.
- Provider error metrics: track per-provider error counts, latency.
- Queue metrics: Redis queue depth, worker throughput.
- `/integrations/status` returns health of each provider (DB, Redis, SMS, voice, push, storage, STT).
- Mobile: local error logging; optional Crashlytics in production build.
- Dashboard: connection status, API error state, WS reconnect state visible in UI.

### 11C — Provider failure handling
- SMS/voice/push failures: mark delivery FAILED; retry with bounded backoff; stop retrying on permanent failure.
- Never falsely report delivery success.
- Show provider health/error on dashboard system status screen.
- Health endpoint `/ready` fails if DB or Redis unavailable.

### 11D — Demo mode isolation
- `DEMO_MODE=true` environment variable enables demo providers.
- Demo providers: `MockSMSProvider`, `MockVoiceProvider`, `MockPushProvider` with in-process logging.
- Visible `DEMO MODE` indicator in dashboard and mobile app.
- Demo reset script: `scripts/demo_reset.py` — reseeds only designated demo data; never touches production config.
- Demo seed data: pre-defined test farmers, animals, cases, outbreaks at test coordinates.
- Designated test phone numbers for demo broadcasts.
- Simulated IVR inject endpoint gated by DEMO_MODE flag; must not bypass business logic.

### Gate 11
- AT-19: Secret scan passes.
- AT-22: Demo reset → only demo data reset; production config untouched.
- AT-24: Provider timeout → bounded retry → FAILED → dashboard shows error.
- `/integrations/status` returns correct health for all providers.
- Rate limiting tested: auth endpoint throttles after threshold.
- CORS: cross-origin request from non-allowlisted origin rejected.
- Replay protection: replayed webhook rejected.
- `pytest backend/tests/test_security.py backend/tests/test_provider_health.py` pass.

---

## Phase 12 — Tests, Demo, and Release

**Goal:** All acceptance tests pass; demo scenarios work on real devices; build pipeline clean.

### 12A — Full acceptance test execution

| AT | Description | Phases covered |
|----|-------------|---------------|
| AT-01 | Registration → DB persist + WS event | 2, 7 |
| AT-02 | Offline registration → restart → record remains | 3 |
| AT-03 | Offline case → PENDING status | 3 |
| AT-04 | Idempotent sync | 4 |
| AT-05 | Sync retry | 4 |
| AT-06 | Physical phone → dashboard real-time | 7 |
| AT-07 | AI confidence + model version displayed | 5 |
| AT-08 | Low confidence → no confirmed + vet review | 5 |
| AT-09 | Animal history → chronological profile | 10 |
| AT-10 | GIS cases → map + radius query | 6 |
| AT-11 | Clustered cases → outbreak detection | 6 |
| AT-12 | IVR webhook + transcript → case + WS event | 8 |
| AT-13 | IVR duplicate callback → no duplicate case | 8 |
| AT-14 | Target preview → server-side count | 9 |
| AT-15 | Broadcast confirm → Redis jobs → status | 9 |
| AT-16 | Inside/outside polygon targeting | 9 |
| AT-17 | Provider accepted ≠ DELIVERED | 9 |
| AT-18 | Farmer role → 403 broadcast | 2, 9 |
| AT-19 | Secret scan | 11 |
| AT-20 | WS reconnect → state refresh | 7 |
| AT-21 | Restart → pending ops remain | 3, 4 |
| AT-22 | Demo reset | 11 |
| AT-23 | Backend tests + dashboard build + Flutter analyze | all |
| AT-24 | Provider failure → retry → FAILED → dashboard | 9, 11 |
| AT-25 | Broadcast + assignment audit | 2, 9 |

### 12B — Demo scenario readiness
- **Demo A** (Registration): real phone → backend → dashboard (AT-01, AT-06).
- **Demo B** (Offline): phone offline → case → restart → sync → dashboard (AT-02, AT-03, AT-05, AT-21).
- **Demo C** (Real IVR): judge calls → IVR → STT → case → dashboard map (AT-12).
- **Demo D** (Emergency): dashboard → select polygon → preview → confirm → test phones receive SMS/voice (AT-15, AT-16).

### 12C — Build pipeline (AT-23)
- `pytest backend/` — all unit + integration tests pass.
- `mypy backend/` — no type errors.
- `ruff backend/` — no lint errors.
- `next build dashboard/` — no TypeScript errors; build succeeds.
- `flutter analyze mobile/` — no errors.
- `flutter test mobile/` — all tests pass.
- Secret scan: no committed secrets.

### Gate 12 (Final Definition of Done)
- AT-01 through AT-25 pass.
- `flutter analyze` clean.
- `next build` succeeds.
- `pytest` passes with all tests.
- No secrets in repository.
- Demo scenarios A–D executable on real devices.
- `IMPLEMENTATION_NOTES.md` documents all ambiguities resolved.

---

## Integration Order Summary

| Integration | Phase introduced | Adapter interface | Mock available |
|-------------|-----------------|-------------------|---------------|
| PostgreSQL/PostGIS | 1 | SQLAlchemy models | Test DB container |
| Redis | 1 | redis-py client | fakeredis |
| JWT / bcrypt | 2 | core/security.py | n/a |
| S3 (object storage) | 4 (media sync) | StorageProvider | MockStorageProvider |
| TFLite (mobile) | 5 | MLModelAdapter | MockMLAdapter |
| Risk engine | 5 | Pure Python; no adapter | In-process |
| Whisper STT | 8 | SpeechToTextProvider | MockSTTProvider |
| TTS (Polly or provider) | 8 | TextToSpeechProvider | MockTTSProvider |
| Exotel | 8 | TelephonyProvider | MockTelephonyProvider |
| Twilio | 8 | TelephonyProvider | MockTelephonyProvider |
| MSG91 (SMS) | 9 | SMSProvider | MockSMSProvider |
| FCM (push) | 9 | PushProvider | MockPushProvider |
| Leaflet + OSM tiles | 6 | Dashboard only | Dev tile server |
| ngrok / Cloudflare Tunnel | Demo only | n/a | n/a |
| Amazon Bedrock (optional) | After Phase 12 | AIProvider | MockAIProvider |
| WhatsApp (optional) | After Phase 12 | WhatsAppProvider | MockWhatsAppProvider |

---

## Testing Gates Summary

| Gate | Phase | Automated tests required | Manual verification |
|------|-------|--------------------------|---------------------|
| 0 | Plan | n/a | Plan internally consistent |
| 1 | DB + infra | Migration apply/rollback; /health; /ready | Docker Compose starts cleanly |
| 2 | Auth + core APIs | Auth, RBAC, farmers, animals, cases | Manual API call via curl/Postman |
| 3 | Mobile foundation | Widget tests, SQLite, offline writes, restart | Physical Android device |
| 4 | Sync engine | Idempotency, batch, retry, media upload | Offline → online → dashboard |
| 5 | AI + risk | Inference, risk engine, advisory, low-conf | AI scan on physical device |
| 6 | Dashboard + GIS | GIS queries, map render, outbreak detection | Browser: all 18 screens load |
| 7 | WebSockets | WS emit, dedup, reconnect | Physical phone → live dashboard |
| 8 | IVR | Webhook, state machine, STT, dedup | Test call to IVR number |
| 9 | Emergency broadcast | Targeting, queue, delivery, retry | Test SMS/voice to test phones |
| 10 | Lab + vaccination | Lab lifecycle, coverage, analytics | Dashboard lab/analytics screens |
| 11 | Hardening | Security, rate limiting, provider health | Secret scan, CORS test |
| 12 | All AT pass | Full test suite | Demo A–D on real devices |

---

## Known Ambiguities (to be resolved in IMPLEMENTATION_NOTES.md)

1. **GIS boundary data** — `districts`, `blocks`, `villages` tables are schema-only until authoritative Maharashtra/India boundary datasets are sourced. Dashboard must gracefully handle absence.
2. **Outbreak detection threshold** — MASTER_SPEC and AI_SPEC do not specify a numeric case-count or time-window for auto-detection. Must be configurable; document the chosen default.
3. **IVR audio retention policy** — IVR_SPEC says "store only audio required by the retention policy" but does not define a retention period. Default to not storing audio in MVP unless required; document this decision.
4. **FCM token management** — MASTER_SPEC specifies FCM for push but does not specify the token registration flow. Mobile must register FCM token with backend on login; backend stores token per user/device. Needs schema column on `users` or a separate `device_tokens` table.
5. **Vaccine inventory management** — Dashboard screen 12 (Vaccine inventory) is listed but no API or schema extends beyond the `vaccinations` table. Will display aggregated data only; schema extension requires a new migration if tracking inventory levels is needed.
6. **Leaflet tile provider** — Production tile provider is configurable but not specified. Default to public OSM tiles for development; must use appropriate provider for production (not abuse public OSM infrastructure per THIRD_PARTY_INTEGRATIONS.md).
7. **TTS provider validation** — THIRD_PARTY_INTEGRATIONS.md says "Amazon Polly or provider-native TTS… after validation." Will start with Exotel/Twilio native TTS for demo; Polly is an optional enhancement requiring separate AWS credentials.
8. **Demo SIMULATE IVR endpoint** — DEMO_MODE.md mentions a flow that injects a test transcript. Exact endpoint path is unspecified. Will be `POST /api/v1/demo/simulate-ivr`, gated by `DEMO_MODE` flag, and must not bypass business logic.

---

*This plan was derived exclusively from MASTER_SPEC.md, ARCHITECTURE.md, and docs/ as they existed at plan creation time. No features were invented beyond what the specifications require.*
