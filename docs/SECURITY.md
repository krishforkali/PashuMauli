# Security Specification

## Authentication
JWT access/refresh flow with secure password hashing.

## Authorization
RBAC enforced server-side:
FARMER
FIELD_VET
DISTRICT_OFFICER
STATE_ADMIN
LAB_USER
SYSTEM_ADMIN

## Secrets
Use environment variables locally and a managed secret store in production.
Never commit:
- AWS credentials
- Bedrock credentials
- telephony tokens
- SMS keys
- JWT secrets
- database passwords.

## API
- HTTPS in deployed environments.
- CORS allowlist.
- request validation.
- rate limiting.
- request size limits.
- webhook signature validation.
- replay protection.
- audit privileged operations.

## Database
Least-privilege DB roles. Parameterized queries/ORM. Backups and migration discipline.

## Mobile
No provider secrets. Secure token storage. Minimize locally retained PII.

## Privacy
Collect only information required for the workflow. Mask phone numbers in ordinary dashboard lists where appropriate.

## Logging
Do not log raw passwords, tokens, complete phone lists, or unnecessary audio/health details.

## Emergency action
Broadcast requires authorized role and explicit confirmation. Record audit event before/with dispatch.
