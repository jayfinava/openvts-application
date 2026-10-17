# Large-fleet live map

> Updated on 2026-10-15: authenticated ordinary fleet maps now use the web
> backend's bounded map-v2 scenes and 100-row server directory. The complete
> baseline behavior described below remains relevant to the legacy/demo and
> existing selected-vehicle engine, rather than the new ordinary fleet path.
> See [the current production review](MOBILE_PRODUCTION_REVIEW_2026-10-15.md)
> for architecture, API verification and rollout requirements.

The Superadmin, Admin, User, Team and Subuser maps share `LiveMapScreen` and its role-aware controller. These changes apply to all of them. The backend source was consulted without modifications.

## Rendering and update limits

- Load the complete authorized fleet through the existing 500-row cursor pages. Do not truncate the fleet to reduce map work.
- Cull vehicles outside the camera bounds with 100 logical pixels of padding before allocating Flutter markers. Panning, rotation and resizing update the fleet layer directly.
- Render at most **250 fleet markers**, using counted grid clusters when a view exceeds that budget. This safety limit also applies at street zoom and with the optional clustering setting disabled.
- Keep an onscreen selected vehicle separate from clusters. Cluster counts preserve every vehicle in the viewport; the full fleet stays available in the searchable drawer. Dense clusters at street zoom open that list.
- Animate at most **100 visible individual vehicles**, with movement frames limited to approximately 30 fps. Static clusters and individual markers stay outside the movement-frame rebuild. Offscreen and clustered vehicles retain their latest telemetry without animation work.
- Suppress ambient ripple animations when more than 40 individual markers are visible. The selected vehicle can retain its ripple.
- Release the hidden drawer's widget tree after its close animation. Opening it reconstructs the complete lazy list; closed drawers do not repeatedly sort the fleet.
- Publish telemetry in batches: 120 ms below 1,000 vehicles, 250 ms from 1,000, and 500 ms from 5,000. The last received packet for each vehicle is retained. Unchanged and stale data do not trigger redundant publications.
- Reuse unchanged immutable vehicle summaries and motion state. Refreshes do not accumulate historical fleet snapshots or motion entries for removed vehicles.
- Release unused vehicle-detail providers after drilldown closes. Pending history requests ignore completion after leaving the map and cannot overwrite a newer request.

The marker budget limits visual work, not the number of tracked vehicles. These changes require no additional package or Android permission.

## Automated verification

Run from the Flutter project:

```powershell
flutter test test/features/live_map
flutter analyze lib/features/live_map test/features/live_map
flutter build apk --debug --no-pub
```

The load tests exercise production controller, planner and screen code with synthetic data. They cover complete 5,000-vehicle updates across roles, stale/repeated packets, dense and distributed locations, high zoom with clustering disabled, camera changes, marker-count bounds and full-fleet retention. Planner tests also cover 10,000 vehicles, invalid coordinates and selected-vehicle visibility.

Verified on 2026-10-09:

- 113 map regression tests passed, including the shared map suite and the existing Superadmin controller/overlay tests.
- Analysis of shared map code, all three role wrappers and map tests passed without issues.
- Android debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
- The actual screen retained all 5,000 vehicles through 12 full-fleet update bursts per role. Search found an offscreen vehicle after drawer reopening. A sparse view animated no more than 100 individuals without rebuilding the static marker layer.
- A planner probe produced 200 layouts for 10,000 retained vehicles with at most 221 groups. This was a workstation test, not an Android memory/frame-rate measurement.

## Android acceptance run

Automated widget tests do not measure Android process memory, GPU usage or vendor-specific behavior. The reported crash had no device model or crash log, so its exact native cause cannot be confirmed from the report alone.

Before rollout, use an authenticated test fleet of 5,000 vehicles on at least one supported low-memory Android phone and a recent Android phone:

1. Run `flutter run --profile` on each device and attach Flutter DevTools.
2. Leave the map receiving live updates for at least 30 minutes. Exercise dense depot views, fleet overview, panning, rotation, street zoom, filters, search, drilldown, and repeated map exit/reentry.
3. Monitor Dart heap, native/process memory and frame timings. After garbage collection, retained memory should settle rather than grow with each update or map visit.
4. Capture `adb logcat` if the process exits, especially `OutOfMemoryError`, native fatal signals or ANR records. Attach the device/RAM, Android version, fleet size and activity to the report.
5. Verify the complete authorized fleet count and fresh telemetry remain correct while automatic visual clustering is active.

A successful synthetic load test is evidence for bounded application work; physical soak testing is the remaining gate for a device-specific stability claim.
