# REPORTS RUNTIME FIX — CHECKPOINT

## Mobile Repository
`D:\Development\openvts-application`

## Read-Only References
- Web: `D:\Development\openVTS-main\openVTS-main\Frontend`
- API: `D:\Development\OpenVTS-API-Reference\OpenVTS-Backend-API-Reference-v1.0.md`

---

## Confirmed Root Causes

### PRIMARY: "All 0 vehicles will be included"
`UserReportWorkspaceNotifier._loadOptions()` fires unawaited on construction.
The workspace screen renders before the async completes.
Fallback: `state.options ?? UserReportOptions(vehicles:[], groups:[])` → count = 0.
`state.optionsError` is populated on failure but NEVER rendered.
`state.isLoadingOptions` is set but NEVER rendered.
Result: user sees "All 0 vehicles" with no spinner, no error, no retry.

### #2: LogsFilters missing `directions`
`LogsFilters.toJson()` returns `{categories, levels}` — `directions` absent.
Backend `GenerateReportDto` expects `{categories, levels, directions, search}`.

### #3: LogsFilters missing `search`
No `search` field in `LogsFilters`. Backend accepts optional `search` (min 3 chars).

### #4: vehicleIds sent as strings not numbers
`ReportVehicleScope.toJson()` sends `vehicleIds: List<String>`.
Backend DTO has `vehicleIds: number[]`. NestJS `@Type(() => Number)` on nested
`Record<string,unknown>` does NOT coerce — backend receives strings, may reject.
Same applies to `vehicleId` (single) and `groupId` (group) — sent as strings.

### #5: Report generation 15-second receive timeout
`normalWriteOptions()` → `receiveTimeout: 15s`. Large fleets timeout silently.
Web has no timeout constraint. Fix: dedicated 60s timeout for report calls only.

---

## Files to Modify

| File | Changes |
|---|---|
| `lib/features/user/models/user_report_state.dart` | Add `directions`, `search` to `LogsFilters`; fix vehicleScope ID types |
| `lib/features/user/models/user_report_model.dart` | Verify UserReportOptions parsing |
| `lib/features/user/controllers/user_report_workspace_notifier.dart` | Expose loading/error/retry state cleanly |
| `lib/features/user/screens/reports/user_report_workspace_screen.dart` | Render options loading, error, retry, empty-vehicles states |
| `lib/features/user/screens/reports/widgets/filters/user_report_filters.dart` | Add directions + search UI to UserLogsReportFilter |
| `lib/features/user/services/user_report_service.dart` | Increase generate timeout to 60s |
| `lib/core/api/api_options.dart` | Add `reportGenerateOptions()` with 60s receive |

## New Test Files
- `test/features/user/models/user_report_model_test.dart`
- `test/features/user/models/user_report_state_test.dart`
- `test/features/user/controllers/user_report_workspace_notifier_test.dart`

---

## Current Implementation Status

| Area | Status |
|---|---|
| Options endpoint (`GET /user/reports/options`) | Correct URL/method; parsing correct; NO loading/error UI |
| Generate endpoint (`POST /user/reports/:key`) | Correct URL/method; 15s timeout too short |
| LogsFilters | Missing `directions` and `search` |
| VehicleScope serialization | IDs sent as strings, should be numbers |
| Options loading UI | Missing spinner, error, retry |
| All 9 report result widgets | Exist; route wiring correct |
| Exports | Client-side; 5 formats; correct |
| Tests | None covering the above bugs |

---

## Phase Status

- [x] Checkpoint created
- [x] Phase 1 — Fix options loading/error/retry UI
- [x] Phase 2 — Vehicle/group selection verification
- [x] Phase 3 — Request contract corrections
- [x] Phase 4 — Complete LogsFilters
- [x] Phase 5 — Generate workflow timeout + validation
- [x] Phase 6 — All 9 reports end-to-end
- [x] Phase 7 — Exports
- [x] Phase 8 — Error diagnostics
- [x] Phase 9 — Tests
- [x] Phase 10 — Final audit + patch

---

## Phase 10 — Final Audit Results (2026-07-29)

### Test suite: 376 pass, 2 pre-existing failures (unrelated to reports)
Pre-existing: `superadmin_map_live_controller_test.dart` (invalid_override), `open_vts_date_time_range_selector_test.dart` (widget finder mismatch — both in initial commit, never modified by this repair)

### All 9 reports: PARITY CONFIRMED
Every report has: options loading/error/empty/success states, cursor pagination, multi-format export (CSV/XLSX/JSON/PDF/HTML), correct row parser field names.

### Additional gaps fixed during Phase 6 audit
- Validation error keys aligned: `sensorVehicle`, `sensorSensor`, `logsVehicle` — errors now surface in UI
- `isLoadingGeofences` forwarded to geofence filter (was always false)
- `isLoadingSensors` forwarded to sensor filter (was always false)
- `vehicleError` forwarded to logs filter (was always null)

### Patch file
`user-reports-runtime-api-fix.patch` — diff of all repair commits from `db4c733` (starting checkpoint) to `20593fc` (Phase 7 complete), 1480 lines covering 15 files.

### Commits in this repair (newest first)
- `20593fc` Phase 7 — multi-format export picker wired up
- `9106777` Phase 6 — parity fixes (validation keys, loading state forwarding)
- `b2007b3` Phase 9 — 44 new unit tests
- `fdb2297` Phase 1-5 combined — core runtime bug fixes
