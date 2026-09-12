# PashuMauli — Implementation Notes

All ambiguities, contradictions, and open decisions discovered during
spec review and repository inspection. Nothing here is silently resolved.
Each item must be closed with an explicit decision before the relevant
phase begins.

---

## IN-08 Phase 5 model artifact and CPH2213 accelerator

**Source:** Phase 5 implementation request.
**Finding:** CPH2213 is connected (`EIEYQCVORWJJKJTG`) and reports Android 13, `arm64-v8a`, and MediaTek `MT6853V/TNZA`. No validated livestock TFLite artifact or licensed LiteRT-LM Gemma 3 1B IT artifact is present in the repository, and no verified SoC-specific LiteRT-LM acceleration artifact was identified.
**Decision:** Keep all model artifacts external to Git. Configure the Android bridge for the safest CPU fallback when an approved Gemma artifact is installed. Do not claim vision inference, LLM generation, latency, multilingual generation, or physical-device AI success until those artifacts are supplied and measured.
**Status:** PARTIALLY RESOLVED — CPU backend configured, model provisioning guide implemented in AdvisoryScreen. Model file must be pushed manually via ADB. Vision model remains StubMLAdapter until a validated livestock TFLite model is acquired.

---

## IN-09 Network error on Android 13 physical device — root cause and fix

**Source:** Phase 5 real-device testing.
**Finding:** The app showed "Network error" on login/register despite ADB reverse being active (`tcp:8000 tcp:8000` confirmed). Root cause: Android 13 may resolve `localhost` to `::1` (IPv6 loopback), but `adb reverse tcp:8000 tcp:8000` only binds on IPv4 `127.0.0.1`. The Dart `http` package then receives a "Connection refused" error because IPv6 port 8000 is not forwarded.
**Fix applied:** Changed `kDefaultApiBaseUrl` default from `http://localhost:8000` to `http://127.0.0.1:8000` in `mobile/lib/data/remote/api_client.dart`. Also improved `ApiResponse.networkError()` factory to provide descriptive, type-specific error messages instead of collapsing all network failures to a generic string.
**Test added:** `test/unit/api_config_test.dart` and `test/unit/phase5_ai_test.dart` both assert `kDefaultApiBaseUrl` does not contain `localhost`.
**Status:** RESOLVED

---


## IN-01 GIS boundary data — no dataset specified

**Source:** DATABASE_SCHEMA.md §GIS reference tables  
**Issue:** The spec says districts/blocks/villages tables "may be added
when authoritative boundary datasets are available." No dataset is named
(e.g., Bhuvan, Survey of India, GADM, DATAMEET). Until a dataset is
chosen and its license confirmed, the three tables are schema-only and
the dashboard boundary overlay will be disabled.  
**Impact:** Phase 1 (migration 003 is schema-only), Phase 6 (dashboard
boundary overlay conditionally disabled).  
**Decision required:** Which boundary dataset? What license? Who loads it?  
**Status:** OPEN

---

## IN-02 Outbreak detection threshold — not specified

**Source:** AI_SPEC.md §Risk engine, MASTER_SPEC.md §15  
**Issue:** No specification defines the numeric case count, geographic
radius, or time window that triggers automatic outbreak detection. The
spec says the feature must exist but gives no parameters.  
**Impact:** Phase 6 (GIS backend outbreak detection logic).  
**Decision required:** Provisional defaults needed before Phase 6 coding.
Proposal: ≥3 cases of the same suspected disease within a 10 km radius
within a 14-day rolling window → creates an outbreak record. This is a
configurable default, not a hardcoded clinical rule.  
**Status:** OPEN — decision needed before Phase 6

---

## IN-03 IVR audio retention policy — not defined

**Source:** IVR_SPEC.md ("Store only audio required by the retention policy")  
**Issue:** No retention duration or policy is stated. In MVP, storing
audio indefinitely is a privacy risk; deleting it immediately removes
audit capability.  
**Impact:** Phase 8 (IVR recording webhook, S3 storage, demo mode).  
**Decision required:** Retain audio for how long? Anonymised after? Only
for cases that become confirmed outbreaks?  
**Provisional MVP default (pending decision):** Do not persist IVR
audio to S3 in MVP unless the call produces a health case AND the
case reaches risk_level HIGH or CRITICAL. Delete raw audio after 30 days.  
**Status:** OPEN

---

## IN-04 FCM device token registration — schema gap

**Source:** MASTER_SPEC.md §12, NOTIFICATION_SPEC.md, DATABASE_SCHEMA.md  
**Issue:** The spec requires FCM push notifications but the database
schema defines no column or table for storing FCM device tokens.
The `users` table has no `fcm_token` field, and there is no
`device_tokens` table.  
**Impact:** Phase 1 migration sequence (a new table or column is
needed), Phase 9 (FCM push delivery).  
**Decision required:** Single FCM token per user, or multiple tokens
(one per device/session)? Recommendation: `device_tokens` table
(user_id FK, token, platform, created_at, last_seen_at) to support
multiple devices per user.  
**Resolution action:** Add migration 016 (create_device_tokens) after
the initial 15-migration sequence if multi-device approach is approved.  
**Status:** OPEN — schema decision required before Phase 9

---

## IN-05 Vaccine inventory management — screen with no schema

**Source:** MASTER_SPEC.md §8 (Dashboard screen 12 "Vaccine inventory"),
DATABASE_SCHEMA.md  
**Issue:** "Vaccine inventory" is listed as a dashboard screen but no
inventory-level entity exists in the schema. The `vaccinations` table
records individual administered vaccinations but has no fields for
stock levels, batch quantities, or expiry.  
**Impact:** Phase 10 (dashboard vaccination screen), Phase 1 (migration
sequence).  
**Decision required:** Is vaccine inventory tracking in MVP scope?
If yes, a new `vaccine_inventory` table is needed (a new migration).
If no, the dashboard screen shows aggregated administered-vaccination
data only and the screen name should be renamed to "Vaccination records"
to avoid implying stock management.  
**Provisional MVP default:** Display aggregated vaccination data only;
no new stock-management table. Document this limitation.  
**Status:** OPEN

---

## IN-06 Leaflet tile provider — production not specified

**Source:** THIRD_PARTY_INTEGRATIONS.md ("Do not bulk-download or
abuse public OSM tile infrastructure. Use an appropriate provider/
self-hosted infrastructure for production.")  
**Issue:** No specific production tile provider is named. Public OSM
tiles are acceptable only for development.  
**Impact:** Phase 6 (dashboard Leaflet configuration), Phase 11
(production hardening).  
**Decision required:** Production tile provider — options include
Mapbox, MapTiler, CARTO, self-hosted OpenMapTiles, or Bhuvan WMS.  
**Provisional dev default:** `https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png`
configured via `NEXT_PUBLIC_MAP_TILE_URL` env var so it is swappable.  
**Status:** OPEN — production provider must be chosen before production
deployment

---

## IN-07 TTS provider — "after validation" left open

**Source:** THIRD_PARTY_INTEGRATIONS.md ("Candidate: Amazon Polly or
provider-native telephony TTS. Must support required Hindi/Marathi demo
voice path after validation.")  
**Issue:** Neither Polly nor provider-native TTS is committed to. Polly
requires separate AWS credentials and a voice ID selection for
Hindi/Marathi. Provider-native TTS quality for Marathi is unknown.  
**Impact:** Phase 8 (IVR TTS prompts).  
**Decision required:** Polly or Exotel/Twilio native TTS for demo? If
Polly: which voice IDs for hi-IN and mr-IN? If provider-native: confirm
language support from actual Exotel/Twilio documentation.  
**Provisional approach:** Default to Exotel/Twilio provider-native TTS
for demo. Abstract behind `TextToSpeechProvider` interface. Add Polly
adapter after validation if native quality is insufficient.  
**Status:** OPEN

---

## IN-08 Demo SIMULATE IVR endpoint — path not specified

**Source:** DEMO_MODE.md ("A SIMULATE IVR flow may inject a prerecorded/
test transcript into the same case-creation service. It must not bypass
business logic.")  
**Issue:** No endpoint path, request shape, or auth requirement is
specified for the simulation flow.  
**Impact:** Phase 8 (IVR), Phase 11 (demo mode isolation), Phase 12
(demo scenario C fallback).  
**Decision required:** Endpoint path and auth model. Must be gated by
`DEMO_MODE=true` so it cannot be called in production.  
**Provisional definition:**
`POST /api/v1/demo/simulate-ivr` — body: `{language, caller_phone,
symptom_keywords[], animal_type, location_hint}` — requires
SYSTEM_ADMIN or FIELD_VET role + DEMO_MODE=true flag. Runs the full
state machine in-process with the mock telephony provider. Returns
case_id on success.  
**Status:** OPEN — confirm provisional definition before Phase 8

---

## IN-09 JWT algorithm and expiry not in .env.example

**Source:** MASTER_SPEC.md §14, SECURITY.md, IMPLEMENTATION_PLAN.md Phase 1  
**Issue:** `.env.example` has `JWT_SECRET` but is missing:
- `JWT_ALGORITHM` (should be `HS256` or `RS256` — must be explicit)
- `JWT_ACCESS_TOKEN_EXPIRY` (e.g., `3600` seconds)
- `JWT_REFRESH_TOKEN_EXPIRY` (e.g., `604800` seconds)
- `CORS_ORIGINS` (required by SECURITY.md CORS allowlist rule)
- `TELEPHONY_PROVIDER` (needed by IVR adapter selection in Phase 8)
- `DEMO_MODE` (bool flag for demo isolation in Phase 11)
- `LOG_LEVEL` (structured logging level from environment, Phase 1)
- `RATE_LIMIT_AUTH_PER_MINUTE` (rate limiting config, Phase 11)
- `WHISPER_MODEL` or `STT_PROVIDER` (Phase 8)
- `TTS_PROVIDER` (Phase 8)
- `FCM_SERVICE_ACCOUNT_JSON` or `FCM_CREDENTIALS_PATH` (Phase 9)
- `OUTBREAK_MIN_CASES` and `OUTBREAK_RADIUS_KM` and `OUTBREAK_WINDOW_DAYS`
  (configurable outbreak detection parameters, Phase 6)
- `STORAGE_PROVIDER` (S3 or mock, Phase 4)
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (needed alongside
  `AWS_REGION` for S3/Bedrock unless using instance role)

**Impact:** Phase 1 (infra scaffolding — .env.example must be complete).  
**Resolution action:** .env.example must be updated in Phase 1 before
any code reads from environment.  
**Status:** OPEN — must be closed in Phase 1 before Gate 1

---

## IN-10 .gitignore pattern `.env.*` excludes `.env.example`

**Source:** .gitignore lines 26–27  
**Issue:** `.gitignore` has `.env.*` on line 26 and then `!.env.example`
on line 27 to un-exclude it. This is correct and intentional. No
conflict. Documented for confirmation.  
**Status:** RESOLVED — pattern is correct

---

## IN-11 CLAUDE.md and AGENTS.md are identical in content

**Source:** CLAUDE.md (root), AGENTS.md (root)  
**Issue:** Both files contain exactly the same content (PashuMauli
implementation rules). CLAUDE.md is for Claude Code tooling;
AGENTS.md is for the Antigravity agent system. Both must remain in sync.
Any update to rules must be applied to both files simultaneously.  
**Impact:** Every phase — both files act as the authoritative rule
source.  
**Status:** DOCUMENTED — not a conflict; both must be kept in sync

---

## IN-12 README.md references CLAUDE.md but AGENTS.md is the active rules file

**Source:** README.md line 8 ("Read `CLAUDE.md`")  
**Issue:** README instructs readers to read CLAUDE.md. The active rules
file used by Antigravity is AGENTS.md. For future contributors using
Antigravity, this could cause confusion.  
**Impact:** Documentation only — no implementation impact.  
**Resolution action (non-blocking):** Consider updating README.md in
Phase 12 to reference both AGENTS.md and CLAUDE.md.  
**Status:** DOCUMENTED — non-blocking

---

## IN-13 backend/, mobile/, dashboard/, scripts/ directories do not exist

**Source:** ARCHITECTURE.md, README.md, AGENTS.md  
**Issue:** All four required component directories are absent from the
repository. The repository contains only specification and planning
documents.  
**Impact:** Phase 1 (must create backend/ scaffold), Phase 3 (mobile/),
Phase 6 (dashboard/), and scripts/ needed for seed/demo utilities.  
**Resolution action:** Create directories in Phase 1 (backend/,
scripts/) and Phase 3 (mobile/) and Phase 6 (dashboard/) respectively.
No application logic goes in any directory before its phase gate.  
**Status:** KNOWN — expected at Phase 0; blocking for Phase 1

---

## IN-14 docker-compose.yml is absent

**Source:** ARCHITECTURE.md §Deployment modes, IMPLEMENTATION_PLAN.md
Phase 1A  
**Issue:** No Docker Compose file exists. PostgreSQL/PostGIS and Redis
are not runnable locally without it.  
**Impact:** Blocks Phase 1 Gate 1 (`alembic upgrade head` requires a
running DB).  
**Resolution action:** Create docker-compose.yml in Phase 1.  
**Status:** KNOWN — expected at Phase 0; blocking for Phase 1

---

## IN-15 No CORS_ORIGINS default in any config

**Source:** SECURITY.md ("CORS allowlist")  
**Issue:** No default CORS origin is documented anywhere in the spec or
`.env.example`. For local development the dashboard runs on a different
port than the backend. Without an explicit allowlist, either all origins
are allowed (insecure) or the dashboard cannot call the API.  
**Provisional:** `CORS_ORIGINS=http://localhost:3000` for development.
Configurable via environment.  
**Status:** OPEN — add to .env.example in Phase 1

---

## IN-16 Whisper STT hosting not resolved

**Source:** THIRD_PARTY_INTEGRATIONS.md, IVR_SPEC.md  
**Issue:** "Whisper-compatible speech-to-text" is required for IVR but
the hosting model is not specified. Options: (a) local Whisper process
on the backend server, (b) OpenAI Whisper API, (c) a self-hosted
Whisper server. Each has different latency, cost, and
credential-management implications.  
**Impact:** Phase 8 (STT adapter implementation).  
**Decision required:** Local subprocess vs remote API?  
**Provisional:** Local `faster-whisper` subprocess for demo (no API
credentials needed); wrap behind `SpeechToTextProvider` interface so it
can be swapped. Document choice.  
**Status:** OPEN — confirm before Phase 8

---

## IN-17 No explicit conflict policy for edited farmer/animal profile fields

**Source:** OFFLINE_SYNC.md §Conflict policy ("For editable profile
fields, use explicit last-write/version conflict rules.")  
**Issue:** "Explicit last-write/version conflict rules" is stated but
not defined. No `version` or `updated_at` comparison algorithm is given.  
**Impact:** Phase 4 (sync engine conflict handling).  
**Resolution:** Closed in Phase 4. For creation operations, `client_id` idempotency
guarantees replay safety (HTTP 200 `ALREADY_APPLIED`). For farmer phone conflict (HTTP 409),
existing record is preserved and marked SYNCED. For animal ear-tag taken (HTTP 409),
the item is marked permanently FAILED to alert the vet. For profile updates, last-write-wins
via `updated_at` ISO-8601 comparison.  
**Status:** CLOSED (Phase 4)

---

## IN-18 S3 upload: signed-URL vs backend-proxy not decided

**Source:** THIRD_PARTY_INTEGRATIONS.md ("Use signed URLs or backend
authorization for protected objects"), STORAGE_SPEC.md  
**Issue:** Two valid approaches for mobile-to-S3 upload: (a) backend
generates a short-lived pre-signed S3 PUT URL that mobile uses
directly; (b) mobile POSTs media to backend which proxies to S3.
Option (a) is more scalable; option (b) is simpler and avoids exposing
S3 bucket structure to client.  
**Impact:** Phase 4 (media sync) and Phase 8 (IVR recording storage).  
**Provisional:** Backend-proxy in MVP (simpler; no S3 credentials on
mobile); switch to signed-URL in a later phase if performance requires.  
**Status:** OPEN — confirm before Phase 4

---

*Last updated: Phase 0 — repository inspection*  
*No issues are silently resolved. Each OPEN item must be explicitly closed
before the phase that depends on it begins.*
