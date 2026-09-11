# WebSocket Events

Endpoint: `/ws/alerts`

All events:
```json
{
  "event": "EVENT_NAME",
  "event_version": 1,
  "event_id": "uuid",
  "timestamp": "ISO-8601",
  "data": {}
}
```

## Events

### FARMER_REGISTERED
Data: farmer_id, name, village_id, location summary.

### ANIMAL_REGISTERED
Data: animal_id, ear_tag_id, farmer_id.

### HEALTH_CASE_CREATED
Data: case_id, source, animal_id, disease, risk_level, location.

### AI_RESULT_AVAILABLE
Data: case_id, model_version, top_prediction, confidence, risk_level.

### OUTBREAK_DETECTED
Data: outbreak_id, disease, risk_level, case_count, geometry/reference.

### LAB_RESULT_UPDATED
Data: sample_id, case_id, status, result summary.

### VACCINATION_UPDATED
Data: animal_id, vaccine, next_due_at.

### BROADCAST_CREATED
Data: broadcast_id, event_type, recipient_count, channels.

### BROADCAST_DELIVERY_UPDATED
Data: broadcast_id, delivery counts/status.

### ALERT_CREATED
Data: alert_id, severity, title, reference_type, reference_id.

## Reliability
WebSocket clients:
- reconnect automatically.
- show connection state.
- after reconnect, fetch authoritative state.
- ignore duplicate event IDs.
- never treat an event as durable storage.
