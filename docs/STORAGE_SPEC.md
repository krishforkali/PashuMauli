# Storage Specification

## PostgreSQL
Structured authoritative data and metadata.

## Object storage
S3 for:
- animal images
- documents
- retained IVR recordings when policy requires
- other large media.

## Mobile
SQLite for offline structured data. Local file storage for photos/audio awaiting upload.

## Naming
Use UUID-based object keys:
`animals/{animal_id}/images/{uuid}.jpg`
`cases/{case_id}/audio/{uuid}.wav`

## Upload lifecycle
LOCAL -> QUEUED -> UPLOADING -> STORED -> ACKNOWLEDGED.

Do not delete local data before successful acknowledgement when offline retention requires it.
