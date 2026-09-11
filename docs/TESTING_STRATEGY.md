# Testing Strategy

## Backend
- unit tests for domain/risk logic
- API tests
- auth/RBAC tests
- database integration tests
- PostGIS spatial tests
- idempotency tests
- provider adapter tests using mocks
- webhook signature tests

## Mobile
- widget tests
- repository/database tests
- offline persistence tests
- sync queue tests
- duplicate/retry tests
- model loading/inference adapter tests

## Dashboard
- component tests
- API integration tests
- WebSocket event tests
- map/target selection tests
- emergency confirmation tests

## End-to-end
- registration -> dashboard
- offline case -> sync -> dashboard
- IVR -> case -> dashboard
- broadcast -> queue -> provider mock -> delivery dashboard

## Quality gates
Before phase completion:
- tests pass
- lint/type checks pass
- build succeeds
- no secrets detected
- acceptance criteria pass
