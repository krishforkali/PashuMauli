# Mobile UI Specification

## Navigation
Use role-aware navigation.

## Screens

### Splash
Loads local configuration/model metadata and session.

### Language
English/Hindi/Marathi.

### Login/Registration
Phone/user credentials; role controlled by backend.

### Home
Quick actions:
- Register farmer
- Add animal
- Report case
- AI scan
- Offline queue
- Notifications

### Farmer profile
Identity, location, phone, animals, cases.

### Animal list
Search by ear-tag/name and status.

### Add animal
Ear-tag, species, breed, sex, age/DOB, location.

### Animal profile
Health history, vaccination, cases, photos.

### Report symptoms
Animal, symptoms checklist, notes, location, photo, submit.

### AI scan
Camera, capture/retry, offline inference indicator, model status.

### AI result
Prediction, confidence, risk, explanation, escalation. Never say “confirmed” solely from AI.

### Advisory
Localized, knowledge-base-backed actions and veterinary escalation.

### Offline queue
Pending/synced/failed records, retry button.

### Sync status
Connectivity, last successful sync, pending count, last error.

### Notifications
Emergency/case assignment/outbreak notifications.

### Settings
Language, permissions, account, model version, diagnostics.

## UX requirements
- Clearly show OFFLINE/ONLINE.
- Never block ordinary offline field work because the server is unreachable.
- Show sync failures plainly.
- Use accessible buttons and large touch targets.
