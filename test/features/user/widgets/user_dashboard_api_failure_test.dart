import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/api/api_endpoints.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/utils/unit_formatter.dart';
import 'package:open_vts/features/user/controllers/user_dashboard_controller.dart';
import 'package:open_vts/features/user/controllers/user_providers.dart';
import 'package:open_vts/features/user/models/user_dashboard_model.dart';
import 'package:open_vts/features/user/screens/dashboard/widgets/user_dashboard_widget_card.dart';
import 'package:open_vts/features/user/screens/dashboard/widgets/user_fleet_status_widget.dart';
import 'package:open_vts/features/user/screens/dashboard/widgets/user_usage_last_7_days_widget.dart';
import 'package:open_vts/features/user/screens/dashboard/widgets/user_weekly_comparison_widget.dart';
import 'package:open_vts/features/user/services/user_dashboard_service.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/l10n/app_localizations_ar.dart';
import 'package:open_vts/l10n/app_localizations_hi.dart';

class _Cache implements LocalCache {
  final _values = <String, Object>{};
  @override
  String? getString(String key) => _values[key] as String?;
  @override
  bool? getBool(String key) => _values[key] as bool?;
  @override
  Future<bool> setString(String key, String value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _values.remove(key);
    return true;
  }
}

class _DashboardAdapter implements HttpClientAdapter {
  final calls = <String, int>{};
  Completer<ResponseBody>? usageRetry;
  int metadataStatus = 200;

  static ResponseBody json(Object data, {int status = 200}) =>
      ResponseBody.fromString(jsonEncode(data), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final path = options.uri.path;
    calls.update(path, (value) => value + 1, ifAbsent: () => 1);
    if (path == ApiEndpoints.user.dashboards) {
      if (metadataStatus != 200) {
        return json({'message': 'private backend diagnostic'},
            status: metadataStatus);
      }
      return json([
        {'id': 'd1', 'name': 'Main Dashboard'}
      ]);
    }
    if (path == ApiEndpoints.user.dashboardById('d1')) {
      return json({
        'id': 'd1',
        'name': 'Main Dashboard',
        'config': {
          'widgets': [
            {'id': 'fleet', 'type': 'fleet_status'}
          ],
        },
      });
    }
    if (path == ApiEndpoints.user.vehicles) return json(<Object>[]);
    if (path == ApiEndpoints.user.dashboardFleetStatus) {
      return json({
        'totalVehicles': 100,
        'withDevice': 100,
        'noDevice': 0,
        'buckets': {'total': 100, 'connected': 100, 'idle': 100},
      });
    }
    if (path == ApiEndpoints.user.dashboardUsageLast7Days &&
        usageRetry != null) {
      return usageRetry!.future;
    }
    if (path == ApiEndpoints.user.dashboardUsageLast7Days ||
        path == ApiEndpoints.user.dashboardWeeklyComparison) {
      // Exercise Dio's real HTTP error path, including its verbose exception.
      return json({'message': 'private backend diagnostic'}, status: 503);
    }
    throw StateError('Unexpected request: $path');
  }

  @override
  void close({bool force = false}) {}
}

const _unavailable =
    'This information is temporarily unavailable. Please try again later.';

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));

  test('metadata 503 is recoverable and failed refresh preserves configuration',
      () async {
    final adapter = _DashboardAdapter()..metadataStatus = 503;
    final dio = Dio(BaseOptions(baseUrl: 'https://dashboard.test'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final controller = UserDashboardController(
      service: UserDashboardService(ApiClient(dio)),
      localCache: _Cache(),
    );
    addTearDown(controller.dispose);

    await controller.loadInitial();
    expect(controller.state.errorMessage, _unavailable);
    expect(controller.state.isLoadingDashboards, isFalse);

    adapter.metadataStatus = 200;
    await controller.loadInitial();
    expect(controller.state.errorMessage, isNull);
    expect(controller.state.orderedWidgets.single.id, 'fleet');
    final previousDashboard = controller.state.selectedDashboard;

    adapter.metadataStatus = 503;
    await controller.refresh();
    expect(controller.state.errorMessage, _unavailable);
    expect(controller.state.isRefreshing, isFalse);
    expect(controller.state.selectedDashboard, same(previousDashboard));
    expect(controller.state.orderedWidgets.single.id, 'fleet');
  });

  testWidgets('503 widgets stay isolated and a single retry can recover',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final adapter = _DashboardAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://dashboard.test'))
      ..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final service = UserDashboardService(ApiClient(dio));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        userDashboardControllerProvider.overrideWith((ref) =>
            UserDashboardController(service: service, localCache: _Cache())),
        unitFormatterProvider
            .overrideWithValue(const UnitFormatter(units: 'KM')),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              UserFleetStatusWidget(
                config: UserDashboardWidgetConfig(
                    id: 'fleet', type: 'fleet_status'),
                refreshTick: 0,
              ),
              UserUsageLast7DaysWidget(
                config: UserDashboardWidgetConfig(
                    id: 'usage', type: 'usage_last_7_days'),
                refreshTick: 0,
              ),
              UserWeeklyComparisonWidget(
                config: UserDashboardWidgetConfig(
                    id: 'weekly', type: 'weekly_comparison'),
                refreshTick: 0,
              ),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text(_unavailable), findsNWidgets(2));
    expect(find.text('100'), findsAtLeastNWidgets(1));
    expect(find.textContaining('DioException'), findsNothing);
    expect(find.textContaining('private backend diagnostic'), findsNothing);
    expect(tester.takeException(), isNull);

    final beforeRetry = Map<String, int>.of(adapter.calls);
    // Failed widgets do not start an automatic retry loop.
    await tester.pump(const Duration(minutes: 1));
    expect(adapter.calls, beforeRetry);

    adapter.usageRetry = Completer<ResponseBody>();
    final usage = find.byType(UserUsageLast7DaysWidget);
    await tester.tap(find.descendant(of: usage, matching: find.text('Retry')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(adapter.calls[ApiEndpoints.user.dashboardUsageLast7Days], 2);
    expect(adapter.calls[ApiEndpoints.user.dashboardWeeklyComparison], 1);
    expect(adapter.calls[ApiEndpoints.user.dashboardFleetStatus], 1);
    expect(
        find.descendant(of: usage, matching: find.text('Retry')), findsNothing);
    final refresh = tester.widget<IconButton>(find.descendant(
      of: usage,
      matching: find.byType(IconButton),
    ));
    expect(refresh.onPressed, isNull);

    adapter.usageRetry!.complete(_DashboardAdapter.json({
      'totals': {'drivenKm': 55.5, 'engineHours': 2},
      'points': <Object>[],
    }));
    await tester.pumpAndSettle();
    expect(find.text(_unavailable), findsOneWidget);
    expect(find.text('55.5 km'), findsOneWidget);
    expect(find.text('100'), findsAtLeastNWidgets(1));
    expect(adapter.calls[ApiEndpoints.user.dashboardUsageLast7Days], 2);
    expect(tester.takeException(), isNull);
  });

  for (final (locale, message) in [
    (const Locale('hi'), AppLocalizationsHi().mobileErrorServiceUnavailable),
    (const Locale('ar'), AppLocalizationsAr().mobileErrorServiceUnavailable),
  ]) {
    testWidgets(
        '${locale.languageCode} error fits a small screen at large text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var retries = 0;
      final request = RequestOptions();
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
            body: Padding(
          padding: const EdgeInsets.all(16),
          child: UserDashboardWidgetError(
            error: DioException.badResponse(
              statusCode: 503,
              requestOptions: request,
              response: Response(requestOptions: request, statusCode: 503),
            ),
            onRetry: () => retries++,
          ),
        )),
      ));
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      await tester.tap(find.byType(TextButton));
      expect(retries, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
