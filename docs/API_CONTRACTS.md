# API Contracts

Base path: `/api/v1`

## Auth
`POST /auth/register`
`POST /auth/login`
`POST /auth/refresh`

## Farmers
`POST /farmers`
`GET /farmers`
`GET /farmers/{id}`
`PATCH /farmers/{id}`

## Animals
`POST /animals`
`GET /animals`
`GET /animals/{id}`
`PATCH /animals/{id}`

## Health cases
`POST /cases`
`GET /cases`
`GET /cases/{id}`
`PATCH /cases/{id}`
`POST /cases/{id}/ai-result`

Case creation supports a client-generated `client_id` for idempotent offline sync.

## Sync
`POST /sync`
`GET /sync/status`
`POST /sync/ack`

Sync endpoint accepts a batch of operations. Response returns per-operation status:
- APPLIED
- ALREADY_APPLIED
- REJECTED
- RETRY

## GIS
`GET /outbreaks`
`GET /outbreaks/heatmap`
`GET /map/cases`
`POST /map/target-preview`

Target preview accepts a validated geographic target and returns recipient count plus non-sensitive summary.

## Lab
`POST /lab-samples`
`GET /lab-samples`
`GET /lab-samples/{id}`
`PATCH /lab-samples/{id}`

## Vaccination
`POST /vaccinations`
`GET /vaccinations`
`GET /vaccinations/coverage`

## IVR
`POST /ivr/incoming`
`POST /ivr/input`
`POST /ivr/recording`
`POST /ivr/status`

Provider-specific signatures must be validated.

## Emergency
`POST /emergency/broadcast`
`POST /emergency/{id}/cancel`
`GET /emergency/broadcasts`
`GET /emergency/broadcasts/{id}`
`GET /emergency/broadcasts/{id}/deliveries`

Creation returns a queued broadcast, not final delivery.

## System
`GET /health`
`GET /ready`
`GET /integrations/status`

## Contract rules
- JSON for application APIs.
- ISO-8601 timestamps.
- UUID identifiers.
- Consistent error envelope:
```json
{"error":{"code":"VALIDATION_ERROR","message":"...","details":{}}}
```
- Authentication required except explicitly public/provider webhooks.
- Provider webhooks use signature verification and replay protection.
- OpenAPI is the source for generated client typing after the human contract is stable.
