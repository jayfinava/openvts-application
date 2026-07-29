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
- [ ] Phase 1 — Fix options loading/error/retry UI
- [ ] Phase 2 — Vehicle/group selection verification
- [ ] Phase 3 — Request contract corrections
- [ ] Phase 4 — Complete LogsFilters
- [ ] Phase 5 — Generate workflow timeout + validation
- [ ] Phase 6 — All 9 reports end-to-end
- [ ] Phase 7 — Exports
- [ ] Phase 8 — Error diagnostics
- [ ] Phase 9 — Tests
- [ ] Phase 10 — Final audit + patch

---

## Exact Next Task
Phase 1: Add loading/error/retry/empty-vehicles UI to workspace options section.
