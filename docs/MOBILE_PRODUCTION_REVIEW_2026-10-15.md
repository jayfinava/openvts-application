# Mobile production review — 2026-10-15

## Scope and conclusion

Compared this Flutter application with `E:\Development\OpenVTS\complete-software`, including the web fleet engine, directory pager, scene socket, metrics loader, backend map-v2 protocol/gateway/service, legacy telemetry gateway, authorization and role-specific map routes. The web checkout was read without modification. Existing mobile work was retained. No screen or route was added.

The largest remaining architectural gap was full-fleet downloading and subscription on the ordinary mobile map. Existing marker culling helped widget count, but did not bound those network, parsing and baseline-refresh costs. Authenticated fleet maps now use the web backend's viewport protocol. This addresses identifiable application risks; the exact reported native crash cannot be attributed without a device crash log.

## Changes

| Finding | Implemented behavior |
| --- | --- |
| Every ordinary map refresh paginated the complete fleet and subscribed to every IMEI. | Authenticated fleet maps use `/map-v2` scenes and server summary counts. Opening the map makes no full-fleet HTTP request or legacy fleet subscription. |
| A directory tied to loaded markers cannot search the entire authorized fleet. | The existing Vehicles drawer uses `/map/v2/vehicles`, server search/status filters and one 100-row page. Previous/next reach all results. Expired directory cursors recover through an authorized locate anchor, with at most one extra 100-row page. |
| History selection could otherwise lose offscreen vehicles after viewport migration. | Server search and pagination are available inside the existing history dialog, independently of the viewport. |
| Full-fleet enrichment repeats expensive browser-day history work. | `/map/v2/metrics` receives at most 100 visible/selected eligible IDs. Requests serialize, cache individual results for 30 seconds and reset on page, access and local-day changes. Binding/service revisions fence enrichment. Metadata-only rows never request metrics. |
| Incomplete snapshots or late packets can replace newer state. | A bounded scene store stages chunks atomically, acknowledges processed chunks/states, applies deltas against a matching base and fences session, scope, projection, interest, source and entity revisions. Sequence gaps request reconciliation. Old-interest batches release server credit without restoring their positions. |
| HTTP fallback can resurrect removed fixes or old tracker bindings. | Explicit null fixes, state removals and changed bindings clear locations. A newer HTTP state can supersede an older matching socket state. Service deadlines clear expired vehicle fixes locally. |
| Covered routes, reconnection and drilldowns can retain work. | Hidden/background/disposed maps cancel HTTP requests, timers and sockets. Namespace ownership is scoped to the map. Server resets and access changes clear live data. Automatic reconnect is bounded to six retries and manual retry uses the existing control. |
| Dense server scenes can exceed the mobile widget budget. | Server clusters and individual vehicles share the existing 250-marker safety limit. Weighted aggregation preserves counts and keeps the selected vehicle separate. Existing animation limits remain 100 individual markers at approximately 30 fps. |
| Repeated normalization allocates unchanged vehicle models. | Models are reused when metadata, state, day metrics and service validity are unchanged. Removed scene/page entries are pruned. |

Camera and row interest updates coalesce for 120 ms; live publications coalesce for 120 ms. Server wire limits remain 25,000 scene records, 200 chunks, 256 records per chunk and 32 MiB serialized scene data. Both installed and staged scenes can exist during replacement; these are bounds on application structures, not a measured phone-memory guarantee.

The existing Alerts tab reads at most 50 full-scope events while visible, refreshed approximately every 15 seconds. It does not require subscriptions to all fleet IMEIs. These map alerts are polled; the rest of the application's push notification behavior is unchanged.

Selected-vehicle routes retain their direct authorized map-v2 lookup and per-device realtime path. Public demo mode retains its isolated demo endpoints/namespace. User, Subuser and Team access continues to use server authorization; administrative drilldowns retain their existing role adapters.

## API comparison

`node tools/audit_backend_routes.mjs E:/Development/OpenVTS/complete-software/backend/src` found 912 routes across 34 controller files. It checked 249 used endpoint builders and 350 direct HTTP method/path calls, with no missing paths or method mismatches. The audit now also checks direct methods and resolves simple builder aliases.

The new map directory, locate, metrics, scene and acknowledgement contracts were separately compared with the current backend implementations and exercised with representative responses. Route inventory excludes unresolved dynamic helpers. It does not establish deployed DTO behavior, authorization or availability. An authenticated deployment smoke test is still required.

## Additional validation repairs

- Registered missing existing QR, tracking and transaction labels in all six localization catalogs, and replaced unreviewed dynamic source expressions with literal localized branches.
- Split the generated text adapter's large string-pattern switch into 32 smaller functions. This preserves source lookup, placeholders, locale resolution and fallback behavior while bounding individual AOT compilation units.
- Removed stale auth-interface references from the unused account-closure view. It remains hidden unless a caller explicitly supplies a deletion callback; no deletion API or account workflow was introduced.
- Declared the already-locked `timezone` dependency directly and corrected analyzer findings without upgrading packages.

## Verification

Initial scalability review results on 2026-10-15:

- `flutter test --reporter expanded`: **2,507 passed**.
- `flutter analyze lib test tool`: **no issues**.
- The additional production-screen acceptance run passed global search, selection of a vehicle outside the original scene and drilldown while retaining one fleet namespace.
- Route audit: **249 endpoint builders and 350 direct method/path calls checked; zero mismatches**.
- `git diff --check`: no whitespace errors.
- `flutter build apk --release --no-pub --split-per-abi`: succeeded for ARMv7, ARM64 and x86-64, producing approximately 47.2 MB, 49.3 MB and 51.8 MB APKs.

The latest artifacts are in `build/app/outputs/flutter-apk/` with names `app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk` and `app-x86_64-release.apk`. **They are unsigned:** this checkout has no `android/key.properties`, and `apksigner verify` confirms no signing manifest. Configure the owner's release signing before distribution; no signing key was created or changed. The build also reports an existing missing Cupertino icon font warning, so platform icon appearance belongs in device acceptance.

Results and build output are recorded in `build/production_review_tests.txt`, `build/production_review_analysis.txt`, `build/backend_route_audit.json` and `build/production_review_apk.txt`. These generated logs are not source artifacts.

The tests include the actual map rendering 5,000 scene leaves, global drawer search, protocol sequencing, malformed directory responses, cancellation/access changes, expiry and metrics caching. Store tests repeatedly replace 10,000 entities and verify retained state does not accumulate. Planner tests combine weighted server clusters and selected leaves while preserving counts within the mobile marker budget. Existing single-vehicle, history, demo, role and application tests also run.

## Dashboard API failure follow-up

The supplied dashboard screenshot showed a 503 response rendered as Dio's full exception. Mobile dashboard failures now retain their typed error until a shared mapper selects a short app-authored message. Backend response bodies, HTML, internal messages and exception descriptions are excluded from dashboard error text. The mapper covers service outages, timeouts, connectivity, rate limits, expired sessions and unavailable/access-denied data. Messages are registered in all six locales.

The same handling applies to dashboard configuration, all dashboard data widgets, alert details and command failures. Local command validation stays specific. Data widgets offer inline Retry for recoverable errors; command submissions are never replayed. Failed widgets stay independent of healthy widgets, and a failed configuration refresh preserves the previous usable configuration. Alert detail failures now have an explicit retry. The dashboard refresh banner reuses the same component. Error controls wrap below the message and retain a 48dp minimum height for narrow screens and large text.

Regression tests exercise the real Dio/API-client/service/provider path with Fleet Status succeeding while Usage and Weekly Comparison return 503, followed by a single pending Usage retry and successful recovery. They check that healthy widgets do not reload, no automatic retry loop starts, loading disables refresh, and private backend details stay hidden. Additional checks cover metadata recovery, configuration retention and Hindi/Arabic at 320px with 200% text scaling.

- `flutter test --no-pub --reporter expanded`: **2,538 passed**.
- `flutter analyze --no-pub`: **no issues**.
- `git diff --check`: no whitespace errors.
- `flutter build apk --release --split-per-abi --no-pub`: succeeded for ARMv7, ARM64 and x86-64 after the final dashboard changes. The existing unsigned-artifact and missing Cupertino font limitations above still apply.
- Logs: `build/dashboard_failure_full_tests.txt`, `build/dashboard_failure_analysis.txt` and `build/dashboard_failure_apk.txt`.

Only the mobile repository was changed. A 503 still means that the requested backend data is unavailable; the mobile UI provides a safe recovery state until the service recovers.

## Reports API parity follow-up

Compared the mobile report flow with the current main project's `Frontend/src/app/user/_components/reports/report-data-source.ts`, report catalog, and backend reports DTO/controller/service and timezone resolver. No main-project files were modified.

Confirmed and repaired mobile differences:

- The old unsupported-platform/browser fallback sent offsets such as `+05:30`. The current database timezone resolver rejects those identifiers with `REPORT_TIMEZONE_UNAVAILABLE` (503). The Flutter browser build now reads the same `Intl.DateTimeFormat().resolvedOptions().timeZone` identifier as the main web app. Native Android/iOS named identifiers are retained. Unsupported numeric offsets are stopped with an app-authored recovery message rather than guessing an IANA zone or substituting UTC.
- Date-only selections now serialize device-local midnight through the following local calendar midnight, matching the web and preserving daylight-saving transitions. Previously they used UTC midnight despite sending a local named zone.
- Pagination retains the successful submitted scope, filters, bounds and time zone even when the draft filters or device zone change. Failed pages preserve rows and the cursor for retry. Duplicate generation is suppressed, loading flags reset consistently, and monotonically increasing request tokens reject responses from before a reset/report change.
- Report responses unwrap the supported nested business/transport envelopes. A missing rows/metadata structure fails explicitly instead of becoming a false empty report.
- Options, generation, sensor-list, pagination and legacy report failures use safe shared error mapping and localized messages. Raw Dio descriptions and backend diagnostics are excluded.

Validation after these changes:

- `flutter test --no-pub --reporter expanded`: **2,564 passed**.
- Focused native report/timezone/localization run: **276 passed**.
- Chrome report API contract run: **15 passed**, covering all nine report types and using the browser's actual `Asia/Calcutta` zone. Tests exercise real Dio/API-client/controller code against controlled responses, including 503 recovery, nested envelopes, cursor consistency, stale responses and malformed success payloads. This is not authenticated deployed-server verification.
- `flutter analyze --no-pub`: **no issues**.
- `flutter build apk --release --split-per-abi --no-pub`: succeeded for ARMv7, ARM64 and x86-64; signing/font limitations above remain.

The installed Windows Flutter browser test harness required two environment workarounds: a root-level test entry (`test/report_browser_contract.dart`) avoids unescaped backslashes in its generated JavaScript selector, and a temporary DevTools interception supplied the SDK's own CanvasKit assets after its Windows route returned 404. The SDK and app assets were not edited for either workaround. The headless test browser was isolated from the existing running app.

Logs are in `build/report_fix_tests.txt`, `build/report_fix_full_tests.txt`, `build/report_fix_browser_tests.txt`, `build/report_fix_analysis.txt` and `build/report_fix_apk.txt`. Fully restart the running Flutter app to load the new conditional browser timezone implementation. Genuine deployment/database outages remain backend failures and are presented safely; verify against the intended authenticated deployment before rollout.

## Monochrome brand follow-up (2026-10-16)

Applied the requested black, gray and white palette across the existing mobile
UI. Map pages, vehicle icons, overlays and landmark colors are exempt and retain
their original colors as clarified on 2026-10-16.
No main-project files or new application pages were added.

- Defined neutral light/dark Material color roles, including error states,
  selection, Cupertino controls, containers, overlays and inverse surfaces.
- Converted non-map screen accents and status indicators,
  dashboard/report charts, support/settings states and Android notification
  accents. Status labels and icons retain meaning without hue. Chart tooltips
  use explicit neutral fills/foregrounds, and pie labels choose black/white for
  contrast; multi-series comparisons use distinct gray tones.
- Rendered non-map app imagery and externally configured UI presentation colors
  in grayscale. Original media, API identifiers and branding settings remain
  intact. Map icons, saved landmark colors, swatches and typed/submitted hex
  selections preserve their original colors without conversion.
- Restored unfiltered `TileLayer` rendering in all 12 map views after the user's
  clarification. The map provider's original road, terrain, satellite and other
  layer imagery is displayed directly in both themes. Original cartographic
  thumbnail colors were also restored in both layer selectors. Vehicle assets
  are untinted. Original status/ripple, route, geofence, POI, history/replay and
  map selection colors are restored. A separate `OpenVtsMapColors` palette
  preserves the original map semantic colors while non-map screens retain the
  monochrome brand palette. Tracking and scalability behavior is unchanged.
- Added regression coverage for app-owned color constants, all theme roles,
  readable foreground/background pairs, chart tooltips and distinct series,
  manual color entry, a colored asset and rendered controls/map selectors in
  both themes. Pixel checks verify neutral non-map UI and original map selector
  colors. User/Admin/Superadmin map checks also verify that actual vehicle asset
  images have no tint or saturation blend. Diagnostic previews are `build/brand-light.png`,
  `build/brand-dark.png` and `build/brand-map-{light,dark}.png`.

Validation after restoring all map presentation colors: **2,576 tests passed**
in the full suite; the focused brand and actual-map run passed **37 tests**.
The map audit found no remaining grayscale image tints or converted original
literal colors, and all **23 original map palette values** match the codebase's
original palette. `flutter analyze --no-pub` and `git diff --check` pass.
Split Android release APKs rebuilt successfully for ARMv7, ARM64 and x86-64.
Logs: `build/map_elements_full_tests.txt`, `build/map_elements_focused_tests.txt`,
`build/map_elements_analysis.txt`, `build/map_elements_diff_check.txt`,
`build/map_elements_remaining_color_audit.txt` and `build/map_elements_apk.txt`.
The unsigned-artifact and existing Cupertino-font limitations above still apply;
no physical-device or iOS acceptance was performed on this Windows host.

## Superadmin and map UX follow-up (2026-10-16)

Compared the existing mobile screens with the main project's vehicle directory,
dashboard administrator list, document endpoints/upload policy, document URL
construction, reverse proxy and map-v2 position/metrics contracts. The main
project was read only; no pages or routes were added.

- Fixed transparent PNG rendering across non-map image displays. The previous
  opaque saturation blend filled transparent source pixels white. A shared
  alpha-preserving color matrix now maintains the neutral UI palette without
  creating a background. Actual profile photos, brand previews and QR images
  no longer receive extra frames, fills or image cropping. Missing-image
  placeholders remain. Map tiles, vehicle icons and map elements remain
  unfiltered in their original colors; source assets are unchanged.
- Activity Log actor options now parse the backend's `uid` and `Name` fields,
  including supported nested response envelopes and duplicate IDs. The filter
  menu uses explicit readable theme colors. Request generations and disposal
  guards prevent older log/filter responses replacing current results.
- Administrator document links now use the active configured API URL and retain
  its reverse-proxy path, including custom server settings. Confirmed upload or
  edit responses are retained when the following list read is stale or fails;
  an older pending read cannot erase a new upload. Image documents have bounded
  inline previews and an existing-dialog zoom preview; other documents open in
  the device's external viewer. Metadata includes the resolved document type.
  Duplicate writes are suppressed, failures use safe messages, and the shared
  5 MiB limit and allowed file types match the web/backend upload policy. Native
  path uploads stream the file rather than making another full byte copy.
- Superadmin Vehicles requests one backend page initially (10 rows by default,
  selectable up to 100). Next/Previous fetch the requested batch. Search is
  debounced, sort/status filters operate on the backend and total counts use its
  pagination metadata. Retired queries cancel; only the last successful bounded
  page is retained during refresh/failure, with old row actions disabled and an
  explicit retry. Unsupported local-only license filtering and status-priority
  sorting were removed so controls do not misrepresent a partial page as the
  entire fleet; license information remains visible on each vehicle.
- Single-vehicle tracking publishes the authorized map-v2 GPS baseline before
  requesting optional daily metrics. The cancelable metrics read cannot delay
  the marker or overwrite a newer position/binding. Authorized valid last-known
  map-v2 coordinates remain visible when the device currently has no satellite
  fix, matching the web contract. Invalid, blocked or unauthorized positions
  remain hidden.
- Fleet scene changes between server clusters and vehicle leaves no longer
  reset a camera chosen by initial fit, cluster navigation or user gestures.
  Cluster taps use bounded, eased zoom/centering; coincident dense depots remain
  accessible through the existing searchable drawer at maximum zoom. Camera
  animation no longer creates retained curve listeners. The existing viewport
  subscription, marker budget and bounded directory remain in place.
- Geofence/POI/route reads run quietly without notices covering the vehicle
  viewport. Optional overlay failures offer retry in the existing map settings
  drawer. Vehicle loading, connection and missing-location feedback remains.

Regression coverage includes real screen/controller/service paths for activity
filters, backend page transitions and cancellation, safe failure/retry, confirmed
uploads with stale reads, document previews/custom API prefixes, disposal and
transparent avatars. Native pixel tests verify that filtered transparent PNGs
remain transparent. The actual map tests exercise a 5,000-vehicle scene,
cluster-to-leaf camera continuity, animated cluster focus, single-vehicle
tracking and deferred/failed geofences without blocking the marker.

Validation after the final PNG alpha correction:

- `flutter test --no-pub --reporter expanded`: **2,592 passed**.
- Focused image/brand/Superadmin run: **26 passed**.
- `flutter analyze --no-pub`: **no issues**.
- `git diff --check`: **no whitespace errors**.
- `flutter build apk --release --split-per-abi --no-pub`: succeeded for ARMv7,
  ARM64 and x86-64. The APKs remain unsigned because the owner's release signing
  configuration is absent. The existing Cupertino icon font warning remains.
- Logs: `build/ux_full_tests.txt`, `build/ux_alpha_tests.txt`,
  `build/ux_final_analysis.txt`, `build/ux_diff_check.txt`,
  `build/ux_release_apk.txt` and `build/ux_apk_signature.txt`.

No authenticated deployment or physical-device acceptance was performed. The
device profiling, release signing and iOS checks below remain necessary before
rollout; these automated results do not establish an absence of native crashes
or sustained memory growth on production hardware.

## Admin and User workflow follow-up (2026-10-16)

Reviewed the requested existing mobile screens against the main project's Admin
controllers/services/DTOs, branding multipart parser and storage, geography
catalog, activity-log inference/query behavior, renewal contract and web profile
URL construction. Only the mobile repository was edited. Existing monochrome
branding and original map imagery/colors are preserved.

- Admin/User notification lists share the same filter/action control, padding,
  type, border, selected contrast and minimum 48dp touch target. Controls wrap on
  narrow screens. Mark all read stays visible, disables when there is nothing
  unread, and shows progress while the write runs.
- Admin Growth Chart lays out its range selector below the heading, wraps the
  range buttons and chooses axis-label density from available width and text
  scaling. All history no longer paints every month on top of adjacent labels.
  Nonzero flat histories remain visible. The rendered 48-month narrow-screen
  preview is `build/admin-growth-all.png`.
- The Admin profile upload consumes the confirmed upload URL without requiring
  a second profile GET to complete successfully. Duplicate submission and
  disposed-controller guards were added; upload failures use safe app-authored
  messages. Profile image URLs now retain the configured API/proxy path, matching
  the web's `apiConfig.buildUrl` behavior. A separate backend blocker remains
  below; these mobile changes do not repair its multipart parser.
- Admin User vehicle assignment accepts multiple checkbox selections, preserves
  selections during search and shows a localized selected count. As authorized
  by the user, it uses the supplied Admin endpoint, which accepts one vehicle
  per request; the supplied bulk array endpoint belongs to User/Subuser scope.
  At most three writes run concurrently. IDs are deduplicated, confirmed links
  move into the assigned list, and only failed selections remain for retry.
- Admin User renewal puts the override reason beside the amount and shows
  validation/API failures inside the drawer. A successful renewal closes the
  form without waiting for payment/vehicle-list refreshes. Confirmed transaction
  data survives a stale refresh. Duplicate submissions are suppressed, existing
  idempotency keys are preserved on retries, and the atomic renewal request gets
  a bounded 60-second response timeout rather than the generic 15 seconds. The
  existing native-iOS subscription policy is unchanged.
- Admin User log filters use readable wrapping controls. Request generations
  reject a late All response or old pagination after changing a filter; a
  pending search debounce cannot override a category tap. Categories use the
  backend's case-insensitive contains query, rather than treating a category
  keyword as the beginning of a role-prefixed action code. The API has a single
  contains-query parameter: choosing a category clears manual search; typing a
  search resets the selected chip to All. A typed search can no longer silently
  mask later category selections.
- Device creation returns its confirmed result before inventory refresh. The
  inline vehicle-creation flow offers a device form and immediately inserts and
  selects that returned device. It does not return a SIM-only boolean into a
  device-typed route. Confirmed vehicle creation also completes before the list
  refresh, so a slow read does not leave the create screen covering the app.
- The shared drawer consumes the keyboard inset once and removes that inset
  from descendants. Driver and Team form footers no longer reserve a second
  keyboard-sized blank area. Narrow-screen tests type into both real forms and
  check the submit/cancel controls above the keyboard.
- Vehicle command template fields expand within available width, constrain the
  menu height and ellipsize long labels. Driver document viewing uses the active
  server with its proxy prefix; image documents open in a bounded zoom dialog,
  and other documents use the external viewer. Unsupported URL schemes are
  rejected. No pages were added.
- User country and state lists now read the backend's `isoCode` field. The
  fallback city field retains/disposes its controller and saves edited text.
  Notification Settings can search vehicles by name, plate or ID across every
  tab. This filters presentation only; hidden vehicles and unsaved toggle
  changes remain in the complete draft/save payload.
- The API-token proof dialog has responsive width, expanded dropdowns, explicit
  spacing between fields and a scrolling body above the keyboard. Existing
  proof, MFA and token-creation contracts are unchanged.
- Report catalog visibility and direct workspace entry were verified against
  per-report permissions. Denied workspaces do not initialize report API
  controllers. A catalog with no report grants now explains the restriction
  rather than reporting an unsuccessful text search.

### Remaining backend profile-upload blocker

The supplied `backend/src/branding/tenant-branding.service.ts` method
`parseLegacyMultipart` retains the file part at line 178 and continues iterating
without consuming its file stream. `saveProfileAsset` only consumes the stream
after the parser returns. With the mobile/web order (`type`, then `file`), this
stalls the iterator and prevents a successful HTTP response.

A controlled reproduction used the main project's installed Fastify/multipart
dependencies without editing that project. It reproduced the stall with 1 KiB
and 128 KiB bodies. Reordering the fields is not a reliable mobile workaround:
file-first uploads still stalled at 128 KiB and 2 MiB. Logs and temporary probes
are in `build/admin_profile_multipart_probe.*` and
`build/admin_profile_file_first_probe.*`.

Reliable profile uploads require the backend parser to consume/persist the file
while iterating, respecting its existing upload limits, or to hand the stream to
storage before waiting for another part. This change was not applied because
the user requested mobile-only changes. No authenticated deployed-server upload
or physical-device acceptance was performed.

Validation of the final mobile changes:

- Added **21** regression cases covering the actual screens and service paths,
  including multi-selection/partial retry, bounded mutation concurrency,
  renewal validation and confirmed completion, nested device-form completion,
  all log chips plus search/category switching and stale reads, country/state
  response shape, active document URLs and image viewing, notification control
  sizing and search/draft preservation, narrow-screen growth history, keyboard
  layout, long templates, token dialog and denied report entry.
- Focused acceptance/localization/shared-widget run: **56 passed**. The final
  full run includes all of these cases.
- `flutter test --no-pub --reporter expanded`: **2,613 passed**.
- `flutter analyze --no-pub`: **no issues**.
- `git diff --check`: **no whitespace errors**.
- `flutter build apk --release --split-per-abi --no-pub`: succeeded for ARMv7,
  ARM64 and x86-64. APKs remain unsigned; the existing Cupertino icon font
  warning and physical-device/iOS acceptance limitations still apply.
- Logs: `build/admin_user_full_tests.txt`, `build/admin_user_ux_regressions.txt`,
  `build/admin_user_acceptance_tests.txt`, `build/admin_user_ux_analysis.txt`,
  `build/admin_user_diff_check.txt` and `build/admin_user_release_apk.txt`.

## Deployment acceptance

Deploy the current backend map-v2 controller/gateway and its existing cluster worker with the API service. The mobile fleet map deliberately does not silently fall back to a full-fleet download when that protocol is unavailable. Existing retry/error controls display connection failure.

No Android phone or emulator was connected during this review; iOS compilation is unavailable on this Windows host. Before rollout:

1. Run an authenticated Android/iOS smoke test against the intended backend for each supported role, including Team metadata-only access and revoked permissions.
2. Profile at least a low-memory Android phone and a recent phone with a 5,000-vehicle fleet for 30 minutes. Exercise fleet overview, dense depots, street zoom, rapid camera movement, directory paging/search, history/replay, background/resume and repeated map entry/exit.
3. Verify retained Dart/native memory settles after garbage collection and map reentry; record frame timings and network volume. Test airplane mode and backend restart/recovery.
4. If the process exits, capture its native/Flutter crash log and device/RAM/OS details. Confirm there is no OOM, fatal signal or ANR before describing the device issue as resolved.
5. Verify the release signing configuration and perform the normal store/platform release checks. A local compilation does not establish store readiness or device stability.

## 2026-10-17: selected tracking, map drawers, avatars and child accounts

Mobile-only follow-up for the two supplied overflow screenshots and account
navigation reports. The main web/backend project was inspected without edits.

- Single-vehicle tracking now treats the authorized socket snapshot like the
  map-v2 baseline: its bounded last-known coordinates can hydrate a missing
  marker even when current GPS quality reports no reception. This applies only
  to authenticated, selected-vehicle snapshots. Ordinary live packets retain
  their GPS quality checks; coordinate bounds, current IMEI/vehicle identity,
  access restrictions and timestamp ordering still apply. Original map imagery
  and vehicle asset colors are unchanged.
- Commands uses one scrolling viewport for the target, template, editable
  payload, send/status controls and lazily built history. Short drawers and the
  keyboard no longer require the complete form to fit above a separate history
  viewport. History labels wrap and template menu rows size to their content.
  The single-vehicle status card also grows with accessibility text.
- Superadmin profile photos use a circular crop before/after upload and during
  upload progress. The shared home avatar also keeps its circular crop. Uploaded
  images retain transparent alpha without an added background fill.
- User Accounts Driver/Subuser cards have one Login action, using the existing
  `GET /user/drivers/:id/login` and `GET /user/subusers/:id/login` contracts.
  Only real USER sessions can start this flow; inactive targets are disabled.
  One request runs at a time, credentials must contain the exact requested role
  and ID plus both tokens, and responses from changed/disposed parent sessions
  are discarded. The existing verified child-session transition preserves
  settings and the parent session stack; signing out returns to the parent.
  Backend ownership, permissions and MFA rules remain authoritative.
- Vehicle Events filters expand within available width, stack on narrow screens
  or large text, truncate long labels, and reset the displayed selections when
  Clear is pressed.

Validation: **29 additional regressions; 2,642 full-suite tests passed**;
`flutter analyze --no-pub` reports no issues; `git diff --check` is clean.
The new map tests cover the real HTTP-to-marker path, missing-position snapshot
recovery and Commands with a 360-pixel viewport, 2x text and keyboard insets for
all three map roles. Account tests cover exact endpoint/session contracts,
malformed credentials, duplicate requests, stale/disposed parents, inactive
accounts, backend outages and explicit retry. Events and avatar tests exercise
the actual widgets. Existing authentication tests cover child sign-out through
the complete parent hierarchy.

Logs: `build/tracking_followup_full_tests.txt`,
`build/tracking_followup_analysis.txt`,
`build/tracking_followup_map_tests.txt`,
`build/tracking_followup_child_tests.txt`,
`build/tracking_followup_account_ui_tests.txt`, and
`build/tracking_followup_diff_check.txt`.

`flutter build apk --release --split-per-abi --no-pub` succeeded for ARMv7,
ARM64 and x86-64. See `build/tracking_followup_release_apk.txt`. Signature
verification confirms the artifacts are unsigned (no signing manifest), as in
the existing project configuration; `build/tracking_followup_apk_signing.txt`
records that result. The existing Cupertino icon-font warning remains. ADB
reported no attached devices, so no device installation was attempted.

Authenticated deployed-server GPS/account-switch testing and physical-device
profiling remain unperformed. The previously documented backend multipart
upload blocker is outside this mobile-only change; the circular-avatar fix
changes rendering after a successful upload, not the backend upload parser.

## 2026-10-17: backend paging for large mobile directories

Mobile-only changes based on the supplied web/backend list contracts. The main
project at `E:/Development/OpenVTS/complete-software` was read without edits.

- Superadmin Admin details: Credit History and Vehicles.
- Admin: User details Vehicles, Vehicles directory, Drivers directory, and
  Inventory Devices/SIM cards.
- User: Vehicles directory.

Each directory requests `page` and `limit` explicitly, initially 20 rows, capped
at 100 per request. Page navigation replaces the current rows and uses backend
totals. It does not download, prefetch, retain or locally slice the entire list.
Search queries go to the backend after a 350 ms debounce, reset to page one and
can find records outside the currently loaded page. Supported filters and sorts
also run on the server. Legacy filters without an equivalent backend contract
are hidden in paged mode. Team-role lists retain their existing behavior because
the supplied Team endpoints do not expose the corresponding paged contracts.

Credit History requests newest entries first, with older entries on later
pages. Displayed balances come from the backend's `balanceAfter` ledger values;
summary counts and credit totals also come from the backend. A response missing
ledger balances is rejected instead of calculating balances from one page.

The User details assignment drawer also loads available vehicles on demand in
pages, with server search. Selections persist across pages/searches, and the
existing bounded Admin assignment requests and partial-failure retry are kept.
Opening the Vehicles tab does not eagerly download all available vehicles.

The shared pager cancels superseded reads, ignores stale responses after scope
changes or disposal, retains the last successful page on errors, and corrects
the page once when deletion removes the last page. Direct and wrapped API
envelopes retain pagination metadata. Account detail widgets clear old local
search state when their account ID changes. Page controls show global row/page
totals and use a bounded page menu, including for directories with 10,000 rows.

Validation: **29 new tests; 2,671 full-suite tests passed**. A subsequent focused
run of **35 tests** passed after the final page-counter/lint changes.
`flutter analyze --no-pub` reports no issues; `git diff --check` is clean.
Production-provider tests use intercepted HTTP responses with 10,000-row
fixtures for all eight endpoints and verify 20-row initial reads, page
replacement, global searches and parameter contracts. Additional regressions
exercise cancellation, disposal, backend outages/retry, invalid payloads,
deletion correction, equivalent auth refreshes, ledger balances, multi-page
assignment and 320-pixel page controls at 1x/2x text.

Logs: `build/list_paging_full_tests.txt`, `build/list_paging_final_tests.txt`,
`build/list_paging_analysis.txt`, and `build/list_paging_diff_check.txt`.
Authenticated deployed-server acceptance and physical-device memory/performance
profiling remain unperformed. These tests validate the mobile implementation
against the supplied backend contracts; they do not measure production-server
response times or guarantee device-specific crash freedom.

`flutter build apk --release --split-per-abi --no-pub` succeeded for ARMv7,
ARM64 and x86-64; see `build/list_paging_release_apk.txt`. The existing Cupertino
icon-font warning remains. ARM64 signature verification reports
`Missing META-INF/MANIFEST.MF`, confirming the existing unsigned release
configuration (`build/list_paging_apk_signing.txt`). Signing credentials were not
added. ADB reported no connected devices, so no installation was attempted.

## 2026-10-17: User notification feeds and account creation parity

Mobile changes benchmarked against the supplied web application and backend in
`E:/Development/OpenVTS/complete-software`, read without modification for this
request. No pages were added; existing monochrome styling and original map
layers/icons remain unchanged.

### Notifications

- The existing User Notifications page now has Vehicle and User tabs, with
  Vehicle selected initially, matching the web flow. Each retains its own
  All/Unread filter, scroll position, rows, cursor, unread count and read actions.
- Vehicle calls use `/user/notifications/vehicle`, its `/:id/read` endpoint and
  `/read-all`; User calls retain `/user/notifications` and its read endpoints.
  An identical numeric ID in the two feeds does not mix their read state.
- Initial reads request 20 rows, with subsequent batches fetched on demand.
  Vehicle history follows the backend continuation cursor even when a restricted
  history window yields fewer than 20 rows or no rows. Explicit null terminates
  that feed; the standard notification endpoint keeps its existing semantics.
- The launcher badge combines two bounded unread-count requests. Firebase
  notification refreshes invalidate both feeds and the combined badge.
- Notifications render lazily, errors remain retryable, and one feed's outage
  leaves the other accessible. Query changes/disposal reject stale responses.
  Failed read actions restore the affected state without undoing other reads.
  A late pagination response cannot reverse an individual or bulk read action.

### Create Subuser and Driver

The references are `CreateSubUserModal.tsx` and the User Accounts `DriversTab.tsx`,
plus `Frontend/src/schemas/fields.ts` and `text-policy.ts`. The Admin Driver form
is a different flow and was not used as the User form contract.

- Subuser fields follow the web order: Name, optional Email, optional mobile
  prefix/number, optional Username, Password, and Active (initially enabled).
  A mobile number requires a prefix; a prefix alone remains valid as on the web.
- Driver fields follow the web order: Name, Username, optional Email, required
  mobile prefix/number, Password, optional Address, Country, optional State,
  City and Pincode. Prefix defaults to +91. Country may default only from the
  current signed-in account's own profile and never overwrites a manual choice.
- Prefixes and location options come from the existing APIs and are searchable.
  Changing Country/State clears dependent selections. Late lookup responses,
  including errors, cannot overwrite a newer selection or changed workspace.
  Failed lookups have explicit retry controls.
- Scoped creation rules match the web: Name/Username up to 35 characters,
  Email up to 65, Password 6–35 printable ASCII characters, mobile 7–15 digits,
  Address up to 120, and Pincode up to 20. Optionality, accepted Unicode names,
  username characters, phone pairing and postal characters match the schemas.
  Display text uses NFC via `unorm_dart`; email is normalized as on the web.
  Passwords are passed unchanged. International postal input uses a text keyboard.
- One scrollable form keeps every field mounted for whole-form validation and
  keeps actions reachable with the keyboard and large text. Busy forms reject
  duplicate submission. Errors retain input. Confirmed creation closes the sheet
  without waiting for the following directory refresh.

Validation: **125 new regressions; 2,796 full-suite tests passed**. The new tests
include 105 cases generated from the actual web schemas, 11 form widget checks
and 9 notification feed/controller checks. They cover Unicode/NFC and credential
boundaries, optional phone pairing, exact request fields, reference APIs, own
profile defaults, stale lookups, duplicate submission, required fields above a
scrolled footer, and 320-pixel forms with 2x text and keyboard insets. Notification
checks cover separate endpoint/read contracts, colliding IDs, count aggregation,
independent failure, restricted cursor windows, disposal and concurrent reads.
The final shared notification regression run also passed all 20 tests.

`flutter analyze --no-pub` reports no issues; `git diff --check` is clean.
`flutter build apk --release --split-per-abi --no-pub` succeeded for ARMv7,
ARM64 and x86-64. The existing Cupertino icon-font warning remains. Resource
inspection resolves `raw/open_vts_notification` to the packaged MP3, whose
SHA-256 matches the supplied original in all three APKs. ARM64 signature
verification confirms the existing unsigned release configuration; no signing
credentials were added.

Final logs: `build/user_notification_forms_verified_tests.txt`,
`build/user_notification_forms_verified_analysis.txt`,
`build/user_notification_forms_final_regressions.txt`,
`build/user_notification_forms_verified_apk.txt`,
`build/user_notification_forms_verified_resources.txt`,
`build/user_notification_forms_verified_audio.json`,
`build/user_notification_forms_verified_signing.txt`, and
`build/user_notification_forms_diff_check.txt`.

Authenticated deployed-server acceptance, notification delivery on physical
devices, and iOS compilation were not performed in this Windows workspace.

## 2026-10-17: Admin and User Vehicles loading correction

Confirmed the existing mobile URLs against both backend controllers/services
and the web Vehicles pages:

- Admin: `GET /admin/vehicles`, backed by `adminService.getVehicles`.
- User: `GET /user/vehicles`, backed by `userService.getUserVehicles`.

Both services return `{action, message, vehicles, pagination}` when paging is
requested. The web reads the `vehicles` array. The mobile page providers were
using the shared pager's default `data` row key, causing valid vehicle responses
to be rejected. Both providers now explicitly select `vehicles`. The shared
pager and API URLs remain unchanged; no backend/web edits were needed.

Initial reads still request 20 rows, later page navigation replaces that batch,
and search runs on the backend. No unpaged fallback or full-directory download
was introduced. The existing cancellation, scope and stale-response protections
remain in place.

The earlier integration fixtures incorrectly put these two directories' rows
under `data`, concealing the contract mismatch. They now use the actual response
shape, as does the existing vehicle-card-to-map navigation fixture. Six new
regressions exercise both production providers with direct/wrapped responses,
initial load, page two, global search and an empty page, plus both actual Vehicles
screens navigating to the next backend page. The Admin card-to-single-map test
also verifies that closing the map preserves the list's search.

Validation: **6 new regressions; 2,802 full-suite tests passed**. The focused paging
integration suite passed all 21 tests, and the existing Admin card-to-single-map
navigation regression passed. `flutter analyze --no-pub` reports no issues;
`git diff --check` is clean.

`flutter build apk --release --split-per-abi --no-pub` succeeded for ARMv7,
ARM64 and x86-64. The existing Cupertino font warning and unsigned release
configuration are unchanged. No application/backend deployment or authenticated
physical-device acceptance was performed; endpoint and payload checks used the
supplied backend/web source and intercepted production-provider requests.

Logs: `build/vehicles_load_focused_tests.txt`,
`build/vehicles_load_map_navigation_test.txt`,
`build/vehicles_load_full_tests.txt`, `build/vehicles_load_analysis.txt`,
`build/vehicles_load_release_apk.txt`, and `build/vehicles_load_diff_check.txt`.
