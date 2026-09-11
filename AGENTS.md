# PashuMauli — Claude Code Rules

## Mission
Build PashuMauli as one connected, offline-first livestock health surveillance platform for SIH Problem Statement 26128.

## Read Before Coding
Read `MASTER_SPEC.md`, `ARCHITECTURE.md`, and all relevant files under `docs/` before implementing a feature.

## Repository
- `backend/`: FastAPI, PostgreSQL/PostGIS, Redis, WebSockets, integrations
- `mobile/`: Flutter, SQLite, offline sync, on-device AI
- `dashboard/`: React/Next.js, TypeScript, Leaflet, command center
- `docs/`: authoritative specifications
- `scripts/`: seed/reset/health-check/demo utilities

## Non-negotiable requirements
1. Mobile field workflows must work without internet.
2. Offline data must survive app restart/device restart and synchronize safely later.
3. Dashboard updates from phone/IVR events must not require browser refresh.
4. IVR and mobile reports must enter the same health-case pipeline.
5. Emergency broadcast must support geographic targeting.
6. Production secrets must never be committed or shipped to mobile/frontend.
7. Provider-specific integrations must be behind interfaces/adapters.
8. Do not invent endpoints, database fields, events, or business rules that contradict the specifications.
9. Demo/simulation code must be isolated from production paths.
10. Do not claim medical diagnosis; AI is a screening/triage aid and low-confidence cases require veterinary review.

## Implementation discipline
- Prefer a modular monorepo, not separate repositories.
- Keep API contracts and WebSocket event names stable.
- Use database migrations; do not silently alter the schema.
- Use typed Dart/TypeScript/Python.
- Validate inputs and handle provider/network failures.
- Write tests for new behavior.
- Run the relevant tests, linting, type checks, and builds before declaring a phase complete.
- If a specification is ambiguous, document the ambiguity in `IMPLEMENTATION_NOTES.md` instead of silently inventing behavior.

## Definition of done
A feature is done only when implementation, tests, documentation, error handling, security requirements, and applicable acceptance tests are complete.
