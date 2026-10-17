# Single-vehicle tracking

The tracking action on each role's vehicle list opens the shared map with an authoritative vehicle ID. The same map controller, overlays, details, events, history and replay are used across Superadmin, Admin and User workspaces (including Team and Subuser permissions).

## Loading and live updates

1. Load the complete authorized map baseline through the existing cursor endpoint. The backend has no vehicle-ID filter on this endpoint. A route's optional IMEI is a hint; the authorized row for its vehicle ID establishes the current device binding.
2. Subscribe only to that binding, request the latest one-device socket snapshot, and use immediate delivery. Initial loading, reconnects and refreshes can therefore recover a position without waiting for the next tracker packet.
3. Reconcile baseline and socket updates by identity and receive time. A sparse HTTP response or a nonlocation packet does not erase the last valid fix for the same allowed binding. Device unassignment, license blocking, service expiry and membership removal do clear obsolete tracking data.
4. Maintain GPS fix time separately from general packet receive time. Invalid fixes and metadata packets cannot advance the displayed GPS time or prevent later valid movement from being accepted.
5. Revalidate authoritative membership after device/service changes and rejected subscription acknowledgements. Revalidation waits for an in-flight baseline and does not repeatedly start concurrent requests.

The backend code at `E:\Development\OpenVTS\complete-software` was used as read-only reference. Missing positions are displayed as missing; no fallback coordinate is presented as the vehicle's GPS location.

## Camera behavior

- Focus at zoom 16 when the first usable location arrives and the map is ready. Initial focus runs once.
- Follow the displayed vehicle position at the current zoom and rotation. Single tracking does not use fleet status filters that could hide its sole vehicle.
- Pan, pinch or rotate to pause follow and cancel an active camera animation. The follow button resumes and recenters at the user's zoom.
- Refresh, reconnect, status transitions and temporary disappearance/reappearance preserve the chosen camera.
- Vehicle details preserve zoom and use the existing live controller. A fix received during the details focus animation is caught up when the animation finishes.
- History and replay suspend live follow. Returning restores the prior live or history camera. A delayed or failed query cannot undo a manual camera gesture.
- A first live fix arriving while history is displayed does not move the historical camera. Initial live focus can run after history closes.

## Details and session lifetime

Sheets and dialogs borrow the map's provider container, avoiding duplicate REST baselines and telemetry connections. The map closes its owned overlays when its account, access or target scope is replaced. Removed vehicles display an unavailable state in an already-open drawer; device commands do not fall back to an obsolete IMEI after unassignment.

The tracking status shows the last accepted GPS receive time separately from connection state, and distinguishes missing GPS, missing device, license blocking and service blocking.

## Verification

```powershell
flutter test test/features/live_map test/shared/models/vehicle_summary_test.dart test/shared/models/vehicle_today_distance_test.dart test/core/router/vehicle_tracking_routes_test.dart test/core/access/mobile_access_test.dart
flutter analyze lib/features/live_map lib/shared/models/vehicle_summary.dart lib/shared/utils/live_vehicle_presentation.dart test/features/live_map
flutter build apk --debug --no-pub
```

Actual-screen regressions exercise delayed snapshots, reconnects, custom zoom/rotation, manual gestures, target disappearance, modal controller identity, live packets during open modals, GPS timestamp isolation, history/replay restoration and scope teardown. Controller regressions exercise sparse refresh races, invalid GPS, ownership mismatches, service expiry, device changes and rejected subscriptions. The existing 5,000-vehicle screen regressions remain part of the verification.

Verified on 2026-10-09: **208 targeted regression tests passed**, including map, model, route/access, existing QR configuration and Superadmin compatibility tests. Static analysis of the changed tracking code and tests reported no issues. The updated Android debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.

Automated tests use the production Flutter flow with controlled REST/socket adapters. A connected Android device and authenticated server session were not available for a physical network/soak run; see `MAP_SCALABILITY.md` for that acceptance procedure.
