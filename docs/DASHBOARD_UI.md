# Dashboard UI Specification

## Command center
Top metrics:
- total farmers
- animals
- active cases
- high-risk cases
- active outbreaks
- vaccination coverage

## Live map
- markers
- clusters
- risk layers
- district/block/village boundaries when available
- case detail drawer
- target drawing tools

## Case management
Filters by disease, risk, district, source, status, date.
Case details include animal, farmer, symptoms, AI result, timeline, assignments, lab status.

## Farmer/animal directories
Search, filters, profile drawer/page.

## Outbreaks
Active clusters, timeline, case count, affected geography, response actions.

## Laboratory
Samples, status, results, referral history.

## Vaccination
Coverage and records.

## Analytics
Cases by time, geography, disease, species; vaccination coverage; response metrics.

## Alert center
Live alerts and acknowledgement.

## Emergency broadcast
Fields:
- hazard/event
- target geography
- language
- message
- channels
- recipient preview
- confirmation
- broadcast progress

Never send an emergency broadcast without an explicit authorization/confirmation action.

## System status
API, DB, Redis, WebSocket, telephony, SMS, storage provider status.

## Real-time UX
New events create non-blocking toast/alert and update relevant views. Critical alerts may play sound if enabled.
