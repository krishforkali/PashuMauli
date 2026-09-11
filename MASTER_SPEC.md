# PashuMauli — Master Product Specification

**Version:** 1.0  
**Status:** Authoritative implementation specification  
**SIH Problem Statement:** 26128 — Efficient systems for early detection, prevention, and management of livestock diseases and animal health issues.

## 1. Product vision
PashuMauli is a connected livestock-health surveillance platform with:
1. Flutter mobile application for farmers/field workers.
2. Government command-center dashboard.
3. Real telephone IVR for feature-phone reporting.
4. One-click geographically targeted emergency broadcast.
5. Shared backend, database, event system, AI/risk engine, and audit trail.

The system must demonstrate real physical-device interaction: a phone can register/report, another laptop dashboard can update in real time, and an authorized dashboard command can trigger alerts to test phones.

## 2. Core principles
- Offline-first, not online-only.
- One unified backend and data model.
- Event-driven real-time dashboard.
- Provider abstraction for telephony/SMS/push/storage.
- Geographic targeting with PostGIS.
- AI is triage/screening assistance, not confirmed veterinary diagnosis.
- Human veterinary escalation for critical/low-confidence cases.
- Demo mode uses the same production APIs/events wherever possible.

## 3. Users and roles
### Farmer
Own profile, animals, health reports, advisories, notifications.
### Field veterinarian / para-vet
Register farmers/animals, record examinations, perform AI scans, manage assigned cases.
### District officer
Monitor district, assign cases, manage outbreaks, initiate targeted broadcasts.
### State administrator
Statewide monitoring, analytics, outbreak response, user administration.
### Laboratory user
Receive samples, update test status/results.
### System administrator
Technical configuration, provider health, audit access.

## 4. Mobile application requirements
Screens:
1. Splash
2. Language
3. Login/registration
4. Home
5. Farmer profile
6. Animal list
7. Add animal
8. Animal profile
9. Vaccination history
10. Report symptoms
11. AI disease scan
12. AI result
13. Advisory
14. Offline queue
15. Sync status
16. Notifications
17. Settings

Functions:
- Farmer/field-worker registration.
- GPS capture when permission is granted.
- Ear-tag based animal identity.
- Animal health history.
- Vaccination records.
- Symptom reporting.
- Camera image capture.
- On-device TFLite screening.
- Local advisory generation/lookup.
- Marathi/Hindi/English UI where implemented.
- Offline storage in SQLite.
- Automatic retry/synchronization.
- Clear sync status.
- Local notifications where supported.

## 5. Offline requirements
The following field functions must remain usable offline:
- Existing local farmer/animal records.
- Add/edit local records.
- Health report creation.
- Photo capture.
- On-device image inference.
- Local advisory/risk logic supported by installed models/rules.
- Queued sync.

Every offline-created entity receives a client-generated UUID and `created_at`/`updated_at` timestamps. Sync is idempotent. Server acknowledgements mark local records as synchronized. Failed operations remain queued with retry metadata.

## 6. Disease/AI requirements
Pipeline:
Image -> local model -> candidate disease -> confidence -> risk engine -> knowledge/rule layer -> advisory/escalation.

Required behaviors:
- Confidence must be displayed.
- Low-confidence predictions must not be presented as confirmed.
- Critical/high-risk cases can be escalated.
- Advisory content must be grounded in an approved knowledge base/rules rather than free-form hallucination.
- Model version must be recorded with each AI result.
- AI processing can be performed locally for supported mobile workflows.
- Cloud AI, if later added, is an enhancement and never a prerequisite for core offline operation.

## 7. Backend
FastAPI service provides:
- authentication/authorization
- farmer/animal/case APIs
- synchronization
- GIS/outbreak queries
- lab/vaccination APIs
- IVR webhooks
- notification/broadcast APIs
- WebSocket event delivery
- health/provider status
- audit logging

PostgreSQL is the source of truth. PostGIS stores/query geographic data. Redis handles queue/cache/background jobs.

## 8. Dashboard
Command center screens:
1. Login
2. Overview
3. Live map
4. Disease cases
5. Farmers
6. Animals
7. Outbreaks
8. Case details
9. Veterinary assignments
10. Laboratory
11. Vaccination
12. Vaccine inventory
13. Analytics
14. Alert center
15. Emergency broadcast
16. Broadcast history
17. User management
18. System status

Live behavior:
- WebSocket connection.
- New farmer registration event.
- New case event.
- IVR case event.
- outbreak event.
- broadcast status event.
- alert sound/visual notification.
- map marker/cluster refresh without full page reload.

## 9. GIS requirements
Use Leaflet for dashboard map UI and OpenStreetMap-derived map data with a configurable tile provider.

Geospatial functions:
- farmer/animal/case points.
- district/block/village boundaries where available.
- radius selection.
- polygon selection.
- case clustering.
- outbreak visualization.
- targeted recipient calculation.

Emergency targeting must be performed server-side using PostGIS, not by trusting a client-provided recipient list.

## 10. IVR
Inbound flow:
1. Telephone provider receives call.
2. Provider invokes secure backend webhook.
3. System identifies caller when possible.
4. Language selection or configured language.
5. Prompt for location/animal/symptoms.
6. Capture recording or speech input.
7. Speech-to-text.
8. Extract structured symptoms/location.
9. Calculate triage risk.
10. Create health case.
11. Persist audit trail.
12. Emit WebSocket event.
13. Provide confirmation to caller.

IVR must support a provider adapter so Exotel can be primary and Twilio can be an alternative.

## 11. Emergency broadcast
Authorized dashboard user:
1. Selects hazard/event type.
2. Selects geographic target by district/block/radius/polygon.
3. Writes/selects localized message.
4. Selects channels: SMS, outbound IVR, FCM, optional WhatsApp.
5. Backend validates authorization and target.
6. PostGIS finds registered recipients.
7. Broadcast is stored.
8. Delivery jobs enter Redis.
9. Workers call provider adapters.
10. Delivery results are recorded.
11. Dashboard receives progress/status events.

The API must return quickly and process fan-out asynchronously.

## 12. Notification channels
- SMS: MSG91 adapter.
- Outbound voice: Exotel adapter; Twilio adapter as fallback.
- App push: Firebase Cloud Messaging.
- WhatsApp: optional phase-2 adapter.
- Dashboard: WebSocket.
- Email is not required for MVP.

## 13. Storage
Use Amazon S3-compatible object storage for animal images, documents, and retained audio where required. PostgreSQL stores metadata and object keys, not large binary blobs.

## 14. Authentication/security
- JWT access tokens.
- Secure password hashing.
- Role-based access control.
- HTTPS/WSS in deployed environments.
- Secrets in environment/secret manager.
- Input validation.
- Rate limiting.
- Audit logs for privileged actions.
- Least-privilege provider credentials.
- Never expose provider/API secrets to Flutter or browser code.
- Minimize exposure of phone numbers and other personal data.
- Do not log raw sensitive payloads unnecessarily.

## 15. Real-time architecture
Backend emits versioned WebSocket events. Dashboard reconnects automatically with exponential backoff and refreshes authoritative state after reconnect.

Event sources:
- mobile API
- IVR
- lab
- broadcast workers
- outbreak engine

WebSockets are for notification/state refresh; PostgreSQL remains authoritative.

## 16. Third-party integration principles
Every external provider must have:
- interface/adapter.
- configuration via environment.
- timeout.
- retry policy appropriate to provider.
- idempotency where supported.
- structured error handling.
- health status.
- mock provider for automated tests.
- demo provider where real credentials are unavailable.

## 17. Technology baseline
### Mobile
Flutter/Dart, SQLite, TensorFlow Lite.
### Backend
Python/FastAPI, PostgreSQL/PostGIS, Redis, WebSockets, Alembic.
### Dashboard
React/Next.js, TypeScript, Leaflet.
### Storage
Amazon S3.
### Notifications
MSG91, FCM.
### Telephony
Exotel primary candidate, Twilio alternative.
### Speech
Whisper-compatible speech-to-text.
### Tunnel for local demo
ngrok or Cloudflare Tunnel.
### Source control
Git/GitHub.

Kafka, Kubernetes, and Golang microservices are explicitly out of MVP scope unless later justified by measured requirements.

## 18. Observability
Backend:
- structured logs
- request IDs
- provider error metrics
- queue metrics
- health endpoints

Mobile:
- local error logging
- optional Crashlytics in production.

Dashboard:
- connection status
- API error state
- WebSocket reconnect state.

## 19. Demo mode
Demo mode must be deterministic and safe:
- seeded farmers/animals/cases.
- designated test phone numbers.
- simulated IVR input fallback.
- simulated notification providers if real providers are unavailable.
- reset script.
- visible DEMO MODE indicator.
- no production credentials.

The demo should prove:
A. phone registration -> live dashboard;
B. offline case -> reconnect -> synchronization;
C. real IVR -> case -> live dashboard;
D. dashboard emergency selection -> targeted test SMS/voice.

## 20. Non-goals for MVP
- Nationwide production deployment.
- Autonomous veterinary diagnosis.
- Training foundation models.
- Kubernetes.
- Kafka cluster.
- P2P mesh as a required feature.
- Full WhatsApp automation.
- Unlimited map tile hosting.
- Large-scale production load claims without testing.

## 21. Definition of done
The platform is complete only when all applicable acceptance tests pass, mobile/backend/dashboard integrate end-to-end, offline persistence works, sync is idempotent, WebSocket updates work, IVR test flow works, emergency broadcast works with a test provider, and secrets are not exposed.

## 22. Implementation order
Phase 0: specification review and plan.
Phase 1: database, migrations, backend foundation.
Phase 2: auth, users, farmers, animals.
Phase 3: mobile UI and SQLite.
Phase 4: sync engine.
Phase 5: AI/risk/advisory.
Phase 6: dashboard/GIS.
Phase 7: WebSockets.
Phase 8: IVR.
Phase 9: emergency broadcast.
Phase 10: lab/vaccination/analytics.
Phase 11: integration hardening.
Phase 12: tests, demo and release.

Do not begin a later phase while the preceding phase's acceptance criteria are failing.
