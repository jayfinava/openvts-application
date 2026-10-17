import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/api/api_endpoints.dart';
import 'package:open_vts/core/platform/platform_time_zone.dart';
import 'package:open_vts/features/user/controllers/user_report_controller.dart';
import 'package:open_vts/features/user/controllers/user_report_workspace_notifier.dart';
import 'package:open_vts/features/user/models/user_report_model.dart';
import 'package:open_vts/features/user/models/user_report_state.dart';
import 'package:open_vts/features/user/screens/reports/widgets/user_report_state_views.dart';
import 'package:open_vts/features/user/services/user_landmark_service.dart';
import 'package:open_vts/features/user/services/user_report_service.dart';
import 'package:open_vts/features/user/services/user_vehicle_service.dart';
import 'package:open_vts/features/user/utils/user_report_validation.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/l10n/app_localizations_hi.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  int status = 200;
  bool hasMore = false;
  int row = 1;
  Object? malformed;
  Completer<ResponseBody>? pending;

  static ResponseBody result({int row = 1, bool hasMore = false}) => json({
        'success': true,
        'data': {
          'action': true,
          'data': {
            'rows': [
              {
                'vehicleId': row,
                'vehicleName': 'Truck $row',
                'distanceKm': 12.5
              }
            ],
            'meta': {
              'generatedAt': '2026-10-15T10:00:00Z',
              'hasMore': hasMore,
              'nextCursor': hasMore ? 'vehicle:$row' : null,
              'source': 'bounded-query',
            },
          },
        },
      });
  static ResponseBody json(Object payload, {int status = 200}) =>
      ResponseBody.fromString(jsonEncode(payload), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (options.method == 'GET' &&
        options.uri.path == ApiEndpoints.user.reportOptions) {
      return json({
        'vehicles': [
          {'id': 7, 'name': 'Truck', 'imei': '123456789012345'}
        ],
        'groups': [],
      });
    }
    if (options.method != 'POST') throw StateError('Unexpected request');
    if (pending != null) return pending!.future;
    final zone = (options.data as Map)['timeZone']?.toString() ?? '';
    // Match the current backend's named-zone requirement. The previous web
    // fallback (+05:30) must fail this contract rather than fabricate empty rows.
    if (RegExp(r'^[+-]|:').hasMatch(zone) || status != 200) {
      return json({
        'statusCode': 503,
        'code': 'REPORT_TIMEZONE_UNAVAILABLE',
        'message': 'private backend diagnostic',
      }, status: 503);
    }
    if (malformed != null) return json(malformed!);
    return result(row: row, hasMore: hasMore);
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _optionsReady(UserReportWorkspaceNotifier notifier) async {
  if (!notifier.state.isLoadingOptions) return;
  final done = Completer<void>();
  final stop = notifier.addListener((state) {
    if (!state.isLoadingOptions && !done.isCompleted) done.complete();
  });
  await done.future;
  stop();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openvts/timezone');
  late _Adapter adapter;
  late Dio dio;
  late UserReportService service;
  late UserReportController controller;

  setUp(() {
    if (!kIsWeb) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => 'Asia/Kolkata');
    }
    adapter = _Adapter();
    dio = Dio(BaseOptions(baseUrl: 'https://reports.test'))
      ..httpClientAdapter = adapter;
    final client = ApiClient(dio);
    service = UserReportService(client);
    controller = UserReportController(
      reportService: service,
      vehicleService: UserVehicleService(client),
      landmarkService: UserLandmarkService(client),
    );
  });
  tearDown(() {
    dio.close(force: true);
    if (!kIsWeb) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    }
  });

  for (final key in UserReportKey.values) {
    test(
        '${key.name} uses the current web/backend transport and parses nested rows',
        () async {
      final zone = await PlatformTimeZone.current();
      expect(zone, isNotEmpty);
      expect(zone, isNot(matches(r'^[+-]|:')));
      final range = key.usesDateOnly
          ? const ReportDateRange.dateOnly(
              startDate: '2026-10-15', endDate: '2026-10-15')
          : const ReportDateRange.dateTime(
              from: '2026-10-14T18:30:00Z', to: '2026-10-15T18:30:00Z');
      final bounds = buildApiDateBounds(range)!;
      final filters = switch (key) {
        UserReportKey.sensor => {
            'sensorIds': ['11']
          },
        UserReportKey.overspeed => {'speedLimitKmh': 80},
        UserReportKey.timeline => {
            'states': ['running', 'stopped']
          },
        _ => <String, dynamic>{},
      };
      final page = await service.generate(
        reportKey: key,
        vehicleScope: key.requiresSingleVehicle
            ? {'mode': 'single', 'vehicleId': 7}
            : {'mode': 'all'},
        dateRange: range.toJson(),
        filters: filters,
        timeZone: zone,
        from: bounds.from,
        to: bounds.to,
      );
      final request = adapter.requests.single;
      expect(request.uri.path, '/user/reports/${key.name}');
      expect(request.method, 'POST');
      expect((request.data as Map)['timeZone'], zone);
      expect((request.data as Map)['filters'], filters);
      expect((request.data as Map)['dateRange'], range.toJson());
      if (key.usesDateOnly) {
        expect((request.data as Map)['from'],
            DateTime(2026, 10, 15).toUtc().toIso8601String());
        expect((request.data as Map)['to'],
            DateTime(2026, 10, 16).toUtc().toIso8601String());
      }
      expect(page.rows.single['distanceKm'], 12.5);
      expect(page.source, 'bounded-query');
    });
  }

  test('genuine 503 is safe and retry retains selections and succeeds',
      () async {
    final notifier = UserReportWorkspaceNotifier(
        initialKey: UserReportKey.distance, controller: controller);
    addTearDown(notifier.dispose);
    await _optionsReady(notifier);
    notifier.setScope(const ReportVehicleScope.multiple(['7']));
    adapter.status = 503;
    await notifier.generate();
    expect(notifier.state.genStatus, ReportGenStatus.error);
    expect(notifier.state.genError,
        'This information is temporarily unavailable. Please try again later.');
    expect(notifier.state.scope.vehicleIds, ['7']);
    adapter.status = 200;
    await notifier.generate();
    expect(notifier.state.genStatus, ReportGenStatus.success);
    expect(notifier.state.genError, isNull);
    expect(adapter.requests.where((r) => r.method == 'POST').length, 2);
  });

  test('paging keeps the submitted dates, scope, filters and timezone',
      () async {
    var zoneCalls = 0;
    final notifier = UserReportWorkspaceNotifier(
      initialKey: UserReportKey.overspeed,
      controller: controller,
      resolveTimeZone: () async =>
          ++zoneCalls == 1 ? 'Asia/Kolkata' : 'America/New_York',
    );
    addTearDown(notifier.dispose);
    await _optionsReady(notifier);
    notifier.setScope(const ReportVehicleScope.single('7'));
    notifier.setOverspeedFilters(const OverspeedFilters(speedLimitKmh: 80));
    adapter.hasMore = true;
    await notifier.generate();
    final original = Map<String, dynamic>.of(
        adapter.requests.last.data as Map<String, dynamic>);
    notifier.setScope(const ReportVehicleScope.group('22'));
    notifier.setDateRange(const ReportDateRange.dateTime(
        from: '2026-10-10T00:00:00Z', to: '2026-10-10T01:00:00Z'));
    notifier.setOverspeedFilters(const OverspeedFilters(speedLimitKmh: 120));
    adapter.row = 2;
    adapter.hasMore = false;
    await notifier.loadMore();
    expect(adapter.requests.last.data, {...original, 'cursor': 'vehicle:1'});
    expect(zoneCalls, 1);
    expect(notifier.state.rows.length, 2);
  });

  test('failed next page preserves rows and retries the same cursor', () async {
    final notifier = UserReportWorkspaceNotifier(
        initialKey: UserReportKey.distance, controller: controller);
    addTearDown(notifier.dispose);
    await _optionsReady(notifier);
    adapter.hasMore = true;
    await notifier.generate();
    adapter.status = 503;
    await notifier.loadMore();
    expect(notifier.state.rows.length, 1);
    expect(notifier.state.isLoadingMore, isFalse);
    expect(notifier.state.loadMoreError, isNot(contains('DioException')));
    adapter.status = 200;
    adapter.hasMore = false;
    await notifier.loadMore();
    expect(notifier.state.rows.length, 2);
    expect(notifier.state.loadMoreError, isNull);
  });

  test('duplicate generation is suppressed and reset rejects stale responses',
      () async {
    final notifier = UserReportWorkspaceNotifier(
        initialKey: UserReportKey.distance, controller: controller);
    addTearDown(notifier.dispose);
    await _optionsReady(notifier);
    adapter.pending = Completer<ResponseBody>();
    final first = notifier.generate();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await notifier.generate();
    expect(adapter.requests.where((r) => r.method == 'POST').length, 1);
    final pending = adapter.pending!;
    notifier.reset();
    adapter.pending = null;
    adapter.row = 2;
    await notifier.generate();
    pending.complete(_Adapter.result(row: 1));
    await first;
    expect(notifier.state.rows.single['vehicleId'], 2);
  });

  test('malformed success does not become a misleading empty report', () async {
    final notifier = UserReportWorkspaceNotifier(
        initialKey: UserReportKey.distance, controller: controller);
    addTearDown(notifier.dispose);
    await _optionsReady(notifier);
    adapter.malformed = {'unexpected': 'not a report'};
    await notifier.generate();
    expect(notifier.state.genStatus, ReportGenStatus.error);
    expect(notifier.state.genError,
        'Unable to complete the request. Please try again.');
  });

  testWidgets('generation error is localized and retry is operable',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('hi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
          body: ReportErrorView(
        message:
            'This information is temporarily unavailable. Please try again later.',
        onRetry: () => retries++,
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.text(AppLocalizationsHi().mobileErrorServiceUnavailable),
        findsOneWidget);
    await tester.tap(find.text(AppLocalizationsHi().retry));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
}
