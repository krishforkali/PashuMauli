# Database Schema

PostgreSQL + PostGIS. Use UUID primary keys. Use UTC timestamps (`timestamptz`). Add created/updated timestamps to mutable entities.

## users
- id UUID PK
- name
- phone UNIQUE
- email nullable
- password_hash
- role
- preferred_language
- village_id nullable
- is_active
- created_at
- updated_at

## farmers
- id UUID PK
- user_id FK users nullable
- name
- phone
- preferred_language
- village_id nullable
- location GEOGRAPHY(Point,4326) nullable
- address_text nullable
- created_at
- updated_at

## animals
- id UUID PK
- ear_tag_id UNIQUE
- farmer_id FK
- species
- breed nullable
- sex nullable
- date_of_birth nullable
- status
- location GEOGRAPHY(Point,4326) nullable
- created_at
- updated_at

## health_cases
- id UUID PK
- client_id UUID UNIQUE nullable for offline idempotency
- animal_id FK nullable
- farmer_id FK nullable
- reported_by FK users nullable
- source enum: MOBILE, IVR, DASHBOARD, IMPORT
- symptoms JSONB
- suspected_disease nullable
- confidence nullable
- risk_score nullable
- risk_level
- status
- location GEOGRAPHY(Point,4326) nullable
- ai_model_version nullable
- advisory_version nullable
- created_at
- updated_at

## ai_results
- id UUID PK
- case_id FK
- model_name
- model_version
- input_type
- predictions JSONB
- top_prediction nullable
- confidence nullable
- inference_ms nullable
- created_at

## vaccinations
- id UUID PK
- animal_id FK
- vaccine
- dose nullable
- administered_at
- next_due_at nullable
- administered_by FK users nullable
- batch_number nullable
- notes nullable

## lab_samples
- id UUID PK
- case_id FK
- sample_type
- sample_code UNIQUE
- status
- lab_id FK users nullable
- collected_at
- received_at nullable
- result nullable
- result_at nullable
- notes nullable

## outbreaks
- id UUID PK
- disease
- risk_level
- geometry GEOGRAPHY(MultiPolygon,4326) or appropriate geometry
- case_count
- detected_at
- status
- created_at
- updated_at

## notifications
- id UUID PK
- user_id FK
- type
- title
- message
- channel
- status
- provider_message_id nullable
- sent_at nullable
- delivered_at nullable
- created_at

## broadcasts
- id UUID PK
- created_by FK users
- event_type
- title
- message
- geometry GEOGRAPHY(MultiPolygon,4326) or target geometry
- recipient_count
- channels JSONB
- status
- created_at
- completed_at nullable

## broadcast_deliveries
- id UUID PK
- broadcast_id FK
- user_id FK
- channel
- status
- provider_message_id nullable
- attempts
- last_error nullable
- sent_at nullable
- delivered_at nullable
- UNIQUE(broadcast_id,user_id,channel)

## sync_operations
- id UUID PK
- client_id UUID UNIQUE
- user_id FK
- entity_type
- entity_id UUID
- operation_type
- payload JSONB
- status
- attempt_count
- last_error nullable
- created_at
- updated_at

## audit_logs
- id UUID PK
- actor_user_id FK nullable
- action
- entity_type
- entity_id nullable
- metadata JSONB
- ip_hash/metadata as appropriate
- created_at

## GIS reference tables
`districts`, `blocks`, `villages` may be added when authoritative boundary datasets are available. Store canonical codes and geometry. Do not invent geographic boundaries.

## Indexes
Create indexes for:
- users.phone
- animals.ear_tag_id
- health_cases.status
- health_cases.created_at
- health_cases.location using GiST
- farmers.location using GiST
- outbreaks.geometry using GiST
- broadcast_deliveries(broadcast_id,status)
- sync_operations(status,created_at)

## Migration rules
All schema changes use Alembic migrations. Never modify production schema manually.
