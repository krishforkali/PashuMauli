# Acceptance Tests

## AT-01 Registration
Given a valid phone and farmer details, when registration is submitted, the farmer is persisted and a dashboard registration event is emitted.

## AT-02 Offline registration
Disable network, create a farmer locally, restart app, and verify the record remains.

## AT-03 Offline health case
Disable network, create a case, verify local persistence and PENDING status.

## AT-04 Idempotent sync
Submit the same client operation twice. Verify exactly one canonical record exists.

## AT-05 Retry
Force a sync failure, restore network, verify automatic retry and successful acknowledgement.

## AT-06 Dashboard real-time
Create a farmer/case from a physical phone. Dashboard updates without browser refresh.

## AT-07 AI confidence
Run a supported image. Verify prediction, confidence, model version and risk are displayed.

## AT-08 Low confidence
Force low confidence. Verify system does not call it confirmed and recommends veterinary review.

## AT-09 Animal history
Create animal, vaccination and case records. Verify chronological profile.

## AT-10 GIS
Create cases at known test coordinates. Verify map rendering and server-side radius query.

## AT-11 Outbreak
Insert clustered test cases. Verify outbreak detection produces expected test cluster.

## AT-12 IVR
Invoke provider/mock webhook and test transcript. Verify one health case and one dashboard event.

## AT-13 IVR duplicate callback
Replay the same provider callback. Verify no duplicate case.

## AT-14 Emergency preview
Select a test radius/polygon. Verify recipient count is computed server-side.

## AT-15 Emergency queue
Confirm broadcast. Verify jobs enter Redis and broadcast status changes to QUEUED/SENDING/SENT or FAILED.

## AT-16 Emergency targeting
Create users inside/outside a test polygon. Verify only eligible inside users are targeted.

## AT-17 Notification truthfulness
Provider mock returns accepted but not delivered. Verify status is SENT, not DELIVERED.

## AT-18 Authorization
Farmer attempts emergency broadcast. Verify 403/authorization failure and audit event.

## AT-19 Secret safety
Search repository/build output for configured secret patterns. Verify no secrets are committed or bundled.

## AT-20 WebSocket reconnect
Stop/restart backend WebSocket. Dashboard reconnects and refreshes authoritative state.

## AT-21 Restart recovery
Restart mobile after offline writes. Verify all pending operations remain.

## AT-22 Demo reset
Run demo reset script. Verify only designated demo data is reset and production configuration is untouched.

## AT-23 Build
Backend tests, dashboard build/typecheck and Flutter analyze/test must pass.

## AT-24 Provider failure
Simulate SMS/voice provider timeout. Verify bounded retry, failure status, and visible dashboard error.

## AT-25 Audit
Perform privileged broadcast and case assignment. Verify actor, action, timestamp and target metadata are recorded.
