import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/features/live_map/models/live_map_role_config.dart';
import 'package:open_vts/features/live_map/models/live_map_vehicle_target.dart';
import 'package:open_vts/features/live_map/services/live_map_vehicle_service.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user()
  ]) {
    test(
        '${config.role.name}: selected tracking reads only its authorized row and metrics',
        () async {
      final requests = <RequestOptions>[];
      final service = LiveMapVehicleService(
          apiClient: ApiClient(_dio((request) {
            requests.add(request);
            return request.uri.path.endsWith('/metrics')
                ? _metrics(request)
                : {'row': _row()};
          })),
          config: config);
      addTearDown(service.dispose);
      final result = await service.getMapTelemetry(
          target:
              const LiveMapVehicleTarget(vehicleId: '42', imei: 'old-device'));
      expect(result.vehicles.single.id, '42');
      expect(result.vehicles.single.imei, 'current-device');
      expect(result.vehicles.single.speed, 35);
      expect(result.vehicles.single.distanceKm, isNull);
      expect(result.vehicles.single.hasValidLocation, isTrue);
      expect(requests.map((r) => r.uri.path), ['/api/map/v2/vehicles/42']);
      final metrics = await service.getTargetMetrics(result.vehicles.single);
      expect(metrics?.distanceKm, 12);
      expect(requests.map((r) => r.uri.path),
          ['/api/map/v2/vehicles/42', '/api/map/v2/metrics']);
      expect(requests.last.queryParameters['ids'], '42');
    });
  }

  for (final blocked in ['license', 'service', 'permission']) {
    test('$blocked restriction never exposes coordinates or requests metrics',
        () async {
      var calls = 0;
      final row = _row();
      if (blocked == 'license') row['isLicenseBlocked'] = true;
      if (blocked == 'service') row['service'] = {'liveAllowed': false};
      if (blocked == 'permission') row['canViewLive'] = false;
      final service = LiveMapVehicleService(
          apiClient: ApiClient(_dio((_) {
            calls++;
            return {'row': row};
          })),
          config: LiveMapRoleConfig.user());
      final result = await service.getMapTelemetry(
          target: const LiveMapVehicleTarget(vehicleId: '42'));
      expect(result.vehicles.single.hasValidLocation, isFalse);
      expect(calls, 1);
    });
  }

  test('metrics from a different binding are ignored', () async {
    final service = LiveMapVehicleService(
        apiClient: ApiClient(_dio((request) {
          if (!request.uri.path.endsWith('/metrics')) return {'row': _row()};
          final metrics = _metrics(request);
          (metrics['rows'] as List).first['bindingVersion'] = 99;
          return metrics;
        })),
        config: LiveMapRoleConfig.user());
    final result = await service.getMapTelemetry(
        target: const LiveMapVehicleTarget(vehicleId: '42'));
    expect(await service.getTargetMetrics(result.vehicles.single), isNull);
    expect(result.vehicles.single.distanceKm, isNull);
    expect(result.vehicles.single.hasValidLocation, isTrue);
  });

  test('authorized last known map position remains visible with no current satellites', () async {
    final row = _row();
    (row['state'] as Map)['satellites'] = 0;
    final service = LiveMapVehicleService(
      apiClient: ApiClient(_dio((_) => {'row': row})),
      config: LiveMapRoleConfig.superadmin());
    addTearDown(service.dispose);
    final result = await service.getMapTelemetry(
        target: const LiveMapVehicleTarget(vehicleId: '42'));
    expect(result.vehicles.single.hasValidLocation, isTrue);
    expect(result.vehicles.single.latitude, (row['state'] as Map)['latitude']);
  });

  test('a different row is rejected without requesting the complete fleet',
      () async {
    var calls = 0;
    final service = LiveMapVehicleService(
        apiClient: ApiClient(_dio((_) {
          calls++;
          return {
            'row': _row()
              ..['id'] = 43
              ..['vehicleId'] = 43
          };
        })),
        config: LiveMapRoleConfig.admin());
    await expectLater(
        service.getMapTelemetry(
            target: const LiveMapVehicleTarget(vehicleId: '42')),
        throwsA(isA<FormatException>()));
    expect(calls, 1);
  });

  test('large production HTTP pages normalize all rows in the worker isolate',
      () async {
    var calls = 0;
    final service = LiveMapVehicleService(
        apiClient: ApiClient(_dio((_) {
          calls++;
          return {
            'items': List.generate(
                500,
                (i) => {
                      ..._row(),
                      'id': i + 1,
                      'vehicleId': i + 1,
                      'imei': 'imei-$i',
                      'telemetry': _row()['state'],
                    }),
            'hasMore': false
          };
        })),
        config: LiveMapRoleConfig.user());
    final result = await service.getMapTelemetry();
    expect(result.vehicles, hasLength(500));
    expect(result.vehicles.map((v) => v.imei).toSet(), hasLength(500));
    expect(calls, 1);
  });

  test('cancelling a fleet page stops pagination and rejects the baseline',
      () async {
    final token = CancelToken();
    var calls = 0;
    final service = LiveMapVehicleService(
        apiClient: ApiClient(_dio((_) {
          calls++;
          token.cancel('Map closed');
          return {
            'items': [_row()],
            'hasMore': true,
            'nextCursor': 'next'
          };
        })),
        config: LiveMapRoleConfig.user());
    await expectLater(
        service.getMapTelemetry(cancelToken: token),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)));
    expect(calls, 1);
  });

  test('closing a service cancels its in-flight detail request', () async {
    final started = Completer<void>();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      started.complete();
      // Simulate a slow connection while allowing Dio cancellation to win.
    }));
    final service = LiveMapVehicleService(
        apiClient: ApiClient(dio), config: LiveMapRoleConfig.user());
    final request = service.getVehicleDetailsByImei('current-device');
    final assertion = expectLater(
        request,
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.cancel)));
    await started.future;
    service.dispose();
    await assertion;
    dio.close(force: true);
  });

  test('nonfinite telemetry values do not escape into map widgets', () {
    final service = LiveMapVehicleService(
        apiClient: ApiClient(Dio()), config: LiveMapRoleConfig.user());
    final vehicle = service.parseTelemetryVehiclePayload({
      'vehicleId': 42,
      'imei': 'current-device',
      'latitude': 20,
      'longitude': 70,
      'speedKph': 'NaN',
      'satellites': 'Infinity',
      'serverTimeMs': double.infinity,
      'course': double.nan,
    });
    expect(vehicle!.speed.isFinite, isTrue);
    expect(vehicle.satellites, isNull);
    expect(vehicle.serverTime, isNull);
    expect(vehicle.headingDegrees, isNull);
  });
}

Map<String, dynamic> _row() => {
      'id': 42,
      'vehicleId': 42,
      'name': 'Selected truck',
      'plateNumber': 'TEST 42',
      'imei': 'current-device',
      'canViewLive': true,
      'isLicenseBlocked': false,
      'service': {'liveAllowed': true},
      'bindingVersion': 7,
      'serviceRevision': 3,
      'state': {
        'vehicleId': 42,
        'latitude': 20.0,
        'longitude': 70.0,
        'speedKph': 35,
        'status': 'running',
        'serverTime': DateTime.now().toUtc().toIso8601String(),
        'odometer': 112,
        'course': 90,
        'ignition': true
      },
    };

Map<String, dynamic> _metrics(RequestOptions request) => {
      'rows': [
        {
          'vehicleId': 42,
          'imei': 'current-device',
          'bindingVersion': 7,
          'serviceRevision': 3,
          'metricsAvailable': true,
          'telemetry': {
            'browserDayKey': request.queryParameters['dayKey'],
            'browserDayStart': request.queryParameters['dayStart'],
            'browserDayBaseOdometer': 100,
            'odometer': 112,
            'distanceToday': 12
          },
        }
      ]
    };

Dio _dio(dynamic Function(RequestOptions) response) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
    handler.resolve(Response<dynamic>(
        requestOptions: request,
        statusCode: 200,
        data: {'action': true, 'data': response(request)}));
  }));
  return dio;
}
