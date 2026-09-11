# Offline Sync Specification

## Local database
SQLite stores:
- user session metadata needed for offline operation
- farmers
- animals
- health cases
- vaccinations
- pending media metadata
- sync operations
- model metadata

## Offline write rule
Every write is committed locally in a transaction before UI reports success.

Every client-created entity uses a UUID generated on-device.

## Queue
Each operation:
- client_id
- entity_type
- entity_id
- operation
- payload
- created_at
- attempt_count
- status

Statuses:
PENDING -> SYNCING -> SYNCED
PENDING -> SYNCING -> FAILED -> PENDING

## Synchronization
1. Detect network.
2. Acquire sync lock.
3. Read pending operations in deterministic order.
4. Send bounded batches.
5. Server validates/authenticates.
6. Server uses client_id/idempotency to avoid duplicates.
7. Server returns per-operation result.
8. Local transaction marks result.
9. Release lock.
10. Schedule retry for failures.

## Conflict policy
- Immutable historical reports are never silently overwritten.
- Server-generated authoritative statuses may override local status after sync.
- For editable profile fields, use explicit last-write/version conflict rules.
- Conflicts are visible to the user when material.

## Media
Images are first stored locally. Upload metadata is queued. Upload actual media to object storage when connectivity is available. Never lose the local original until successful server acknowledgement if retention policy requires it.

## Restart guarantee
Pending records survive app restart and device restart.

## Security
Encrypt sensitive local storage where practical. Never store long-lived provider secrets in the app.
