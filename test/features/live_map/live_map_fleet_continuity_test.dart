import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/socket/socket_service.dart';
import 'package:open_vts/core/storage/token_storage.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/live_map/controllers/live_map_controller.dart';
import 'package:open_vts/features/live_map/models/live_map_role_config.dart';
import 'package:open_vts/features/live_map/models/live_map_vehicle_target.dart';
import 'package:open_vts/features/live_map/services/live_map_events_service.dart';
import 'package:open_vts/features/live_map/services/live_map_vehicle_service.dart';
import 'package:open_vts/features/notifications/models/app_notification.dart';
import 'package:open_vts/features/notifications/models/notification_page.dart';
import 'package:open_vts/shared/models/user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));
  requestLifecycleTests();

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(), // Team uses the same authorized Admin endpoints.
    LiveMapRoleConfig.user(), // Subuser uses its authorized User endpoints.
  ]) {
    test(
      '${config.role.name}: loads all 220 vehicles over all cursor pages',
      () async {
        final requests = <RequestOptions>[];
        final clock = DateTime.now().toUtc();
        final service = LiveMapVehicleService(
          apiClient: ApiClient(
            _dio((request) {
              requests.add(request);
              final start =
                  int.tryParse('${request.queryParameters['cursor']}') ?? 0;
              final end = (start + 100).clamp(0, 220);
              return {
                'items': List.generate(
                  end - start,
                  (i) => _record(
                    '${start + i + 1}',
                    clock,
                    speed: (start + i) < 110 ? 32 : 0,
                    inactive: (start + i) >= 165,
                  ),
                ),
                'hasMore': end < 220,
                'nextCursor': end < 220 ? '$end' : null,
              };
            }),
          ),
          config: config,
        );
        final result = await service.getMapTelemetry(
          refreshKey: 'same-snapshot',
        );
        expect(result.vehicles, hasLength(220));
        expect(result.allCount, 220);
        expect(result.runningCount, 110);
        expect(result.stopCount, 55);
        expect(result.inactiveCount, 55);
        expect(requests, hasLength(3));
        expect(requests.map((r) => r.queryParameters['cursor']), [
          null,
          '100',
          '200',
        ]);
        expect(
          requests.every((r) => r.queryParameters['limit'] == 500),
          isTrue,
        );
        expect(
          requests.map((r) => r.queryParameters['dayStart']).toSet(),
          hasLength(1),
        );
        expect(requests.map((r) => r.queryParameters['rk']).toSet(), {
          'same-snapshot',
        });
        expect(
          requests.every(
            (r) => r.uri.path == '/api${config.mapTelemetryEndpoint}',
          ),
          isTrue,
        );
      },
    );
  }

  test(
    'legacy array response remains supported and deduplicates row identities',
    () async {
      final clock = DateTime.now().toUtc();
      final service = LiveMapVehicleService(
        apiClient: ApiClient(
          _dio(
            (_) => [
              _record('1', clock),
              _record('1', clock),
              _record('2', clock),
            ],
          ),
        ),
        config: LiveMapRoleConfig.user(),
      );
      expect((await service.getMapTelemetry()).allCount, 2);
    },
  );

  test('later page failure never returns a silently truncated fleet', () async {
    var calls = 0;
    final service = LiveMapVehicleService(
      apiClient: ApiClient(
        _dio((request) {
          calls++;
          if (calls > 1) throw StateError('network interrupted');
          return {
            'items': [_record('1', DateTime.now().toUtc())],
            'hasMore': true,
            'nextCursor': '1',
          };
        }),
      ),
      config: LiveMapRoleConfig.superadmin(),
    );
    await expectLater(service.getMapTelemetry(), throwsA(isA<DioException>()));
    expect(calls, 2);
  });

  test(
    'account switch during pagination aborts before requesting another page',
    () async {
      var user = const CurrentUser(
        id: 'first',
        name: 'First',
        email: '',
        role: UserRole.user,
      );
      var calls = 0;
      final service = LiveMapVehicleService(
        apiClient: ApiClient(
          _dio((_) {
            calls++;
            user = const CurrentUser(
              id: 'second',
              name: 'Second',
              email: '',
              role: UserRole.user,
            );
            return {
              'items': [_record('1', DateTime.now().toUtc())],
              'hasMore': true,
              'nextCursor': '1',
            };
          }),
          activeUser: () => user,
        ),
        config: LiveMapRoleConfig.user(),
      );
      await expectLater(service.getMapTelemetry(), throwsStateError);
      expect(calls, 1);
    },
  );

  test(
    'hasMore without a cursor fails rather than hiding remaining vehicles',
    () async {
      final service = LiveMapVehicleService(
        apiClient: ApiClient(
          _dio(
            (_) => {
              'items': [_record('1', DateTime.now().toUtc())],
              'hasMore': true,
            },
          ),
        ),
        config: LiveMapRoleConfig.admin(),
      );
      await expectLater(service.getMapTelemetry(), throwsStateError);
    },
  );

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user(),
  ]) {
    _testMapWidgets(
      '${config.role.name}: stationary speed zero changes state and times at identical coordinates',
      (tester) async {
        final harness = _Harness(config);
        harness.initialize();
        await _flush(tester);
        harness.socket.telemetry.single.connect();
        final connection = harness.socket.telemetry.single;
        harness.clock = harness.clock.add(const Duration(seconds: 1));
        connection.event('telemetry:update', _packet(harness.clock, speed: 0));
        await _flush(tester);
        final vehicle = harness.controller.state.telemetry.vehicles.single;
        expect(vehicle.speed, 0);
        expect(vehicle.status, 'stop');
        expect(vehicle.latitude, 40.7);
        expect(vehicle.name, 'Vehicle 1');
        expect(vehicle.id, '1');
        expect(vehicle.serverTime, harness.clock);
        expect(harness.controller.state.telemetry.runningCount, 0);
        expect(harness.controller.state.telemetry.stopCount, 1);
        final subscription = connection.emits
            .singleWhere((e) => e.$1 == 'telemetry:subscribe')
            .$2 as Map;
        expect(subscription['snapshot'], isFalse);
        if (config.role != LiveMapRole.superadmin) {
          expect(subscription['imeis'], ['imei-1']);
          expect(subscription['delivery'], 'batch');
        }
      },
    );
  }

  _testMapWidgets(
    'large fleet chunks every IMEI and merges a complete batch once',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.admin());
      h.service.rows = List.generate(
        10001,
        (index) => _record('${index + 1}', h.clock),
      );
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      final subscriptions = socket.emits
          .where((event) => event.$1 == 'telemetry:subscribe')
          .map((event) => event.$2 as Map)
          .toList();
      expect(subscriptions, hasLength(3));
      expect(subscriptions.map((event) => (event['imeis'] as List).length), [
        5000,
        5000,
        1,
      ]);
      expect(
        subscriptions.expand((event) => event['imeis'] as List).toSet(),
        hasLength(10001),
      );
      h.clock = h.clock.add(const Duration(seconds: 1));
      socket.event('telemetry:update:batch', {
        'records': List.generate(
          220,
          (index) => {
            ..._packet(h.clock, speed: 0),
            'imei': 'imei-${index + 1}',
          },
        ),
      });
      await tester.pump(const Duration(milliseconds: 500));
      expect(h.controller.state.telemetry.allCount, 10001);
      expect(h.controller.state.telemetry.stopCount, 220);
      expect(h.controller.state.telemetry.runningCount, 9781);
    },
  );

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user(),
  ]) {
    _testMapWidgets(
      '${config.role.name}: 5000 live vehicles retain all updates with bounded publications',
      (tester) async {
        final h = _Harness(config);
        h.clock = DateTime(2026, 10, 9, 12).toUtc();
        h.service.rows = List.generate(
          5000,
          (index) => _record('${index + 1}', h.clock),
        );
        h.initialize();
        await _flush(tester);
        final socket = h.socket.telemetry.single..connect();
        final original = h.controller.state.telemetry;
        var publications = 0;
        final stopListening = h.controller.addListener((state) {
          if (!identical(state.telemetry, original)) publications++;
        }, fireImmediately: false);
        h.clock = h.clock.add(const Duration(seconds: 1));
        // A full fleet burst followed by sparse patches must preserve data,
        // not truncate the baseline or drop fields while coalescing updates.
        socket.event('telemetry:update:batch', {
          'records': List.generate(
            5000,
            (index) => {
              ..._packet(h.clock, speed: index.isEven ? 0 : 45),
              'imei': 'imei-${index + 1}',
            },
          ),
        });
        socket.event('telemetry:update', {
          'imei': 'imei-1',
          'serverTime':
              h.clock.add(const Duration(seconds: 1)).toIso8601String(),
          'ignition': false,
        });
        await tester.pump(const Duration(milliseconds: 125));
        expect(publications, 0);
        await tester.pump(const Duration(milliseconds: 375));
        final telemetry = h.controller.state.telemetry;
        expect(publications, 1);
        expect(telemetry.vehicles, hasLength(5000));
        expect(telemetry.runningCount, 2500);
        expect(telemetry.stopCount, 2500);
        expect(
          telemetry.vehicles.map((vehicle) => vehicle.imei).toSet(),
          hasLength(5000),
        );
        expect(telemetry.vehicles.first.speed, 0);
        expect(telemetry.vehicles.first.ignition, isFalse);
        expect(telemetry.vehicles.first.name, 'Vehicle 1');

        // Older repeat traffic must not cause further fleet publications.
        socket.event('telemetry:update:batch', {
          'records': List.generate(
            5000,
            (index) => {
              ..._packet(
                h.clock.subtract(const Duration(minutes: 1)),
                speed: 99,
              ),
              'imei': 'imei-${index + 1}',
            },
          ),
        });
        await tester.pump(const Duration(milliseconds: 500));
        expect(publications, 1);
        socket.event('telemetry:update', {
          'imei': 'imei-1',
          'serverTime':
              h.clock.add(const Duration(seconds: 3)).toIso8601String(),
          'ignition': true,
        });
        await tester.pump(const Duration(milliseconds: 500));
        final patched = h.controller.state.telemetry;
        expect(publications, 2);
        expect(patched.vehicles.first.ignition, isTrue);
        expect(patched.vehicles[1], same(telemetry.vehicles[1]));
        await tester.pump(const Duration(seconds: 5));
        expect(publications, 2);
        stopListening();
      },
    );
  }

  _testMapWidgets(
    'unchanged fleet refresh reuses summaries and day rollover resets Today',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.clock = DateTime(2026, 10, 9, 12).toUtc();
      h.service.rows = List.generate(
        5000,
        (index) => _record('${index + 1}', h.clock),
      );
      h.initialize();
      await _flush(tester);
      final original = h.controller.state.telemetry;
      await h.controller.refreshTelemetry();
      expect(h.controller.state.telemetry, same(original));
      h.clock = h.clock.add(const Duration(days: 1));
      await tester.pump(const Duration(seconds: 5));
      final nextDay = h.controller.state.telemetry;
      expect(nextDay.vehicles, hasLength(5000));
      expect(nextDay.vehicles.first.browserDayKey, '2026-10-10');
      expect(nextDay.vehicles.first.distanceKm, isNull);
      expect(nextDay.vehicles.first, isNot(same(original.vehicles.first)));
    },
  );

  _testMapWidgets(
    'older packet cannot regress speed, status, coordinates, or receive time',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      final original = h.controller.state.telemetry.vehicles.single;
      socket.event('telemetry:update', {
        ..._packet(h.clock.subtract(const Duration(minutes: 1)), speed: 0),
        'latitude': 40.71,
      });
      await _flush(tester);
      final vehicle = h.controller.state.telemetry.vehicles.single;
      expect(vehicle.speed, original.speed);
      expect(vehicle.status, 'running');
      expect(vehicle.latitude, original.latitude);
      expect(vehicle.serverTime, original.serverTime);
    },
  );

  _testMapWidgets(
    'sparse telemetry preserves missing speed, name, ID and existing metrics',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      h.clock = h.clock.add(const Duration(seconds: 1));
      socket.event('telemetry:update', {
        'imei': 'imei-1',
        'serverTime': h.clock.toIso8601String(),
        'ignition': false,
      });
      await _flush(tester);
      final vehicle = h.controller.state.telemetry.vehicles.single;
      expect(vehicle.speed, 32);
      expect(vehicle.name, 'Vehicle 1');
      expect(vehicle.id, '1');
      expect(vehicle.ignition, isFalse);
      expect(vehicle.latitude, 40.7);
      expect(vehicle.status, 'running');
    },
  );

  _testMapWidgets(
    'reconnect resubscribes and catches updates missed during outage',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.admin());
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      socket.drop();
      h.clock = h.clock.add(const Duration(seconds: 3));
      h.service.rows = [_record('1', h.clock, speed: 0)];
      socket.connect();
      await _flush(tester);
      expect(h.service.calls, 2);
      expect(
        socket.emits.where((e) => e.$1 == 'telemetry:subscribe'),
        hasLength(2),
      );
      expect(h.controller.state.telemetry.stopCount, 1);
    },
  );

  _testMapWidgets(
    'resume recovers disconnected snapshot and does not poll while backgrounded',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      h.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      h.clock = h.clock.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 35));
      expect(h.service.calls, 1);
      h.service.rows = [_record('1', h.clock, speed: 0)];
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await _flush(tester);
      expect(h.service.calls, 2);
      expect(h.controller.state.telemetry.stopCount, 1);
    },
  );

  _testMapWidgets(
    'silent running telemetry ages into stop without another packet',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      h.clock = h.clock.add(const Duration(minutes: 2));
      await tester.pump(const Duration(seconds: 5));
      await _flush(tester);
      expect(h.controller.state.telemetry.runningCount, 0);
      expect(h.controller.state.telemetry.stopCount, 1);
    },
  );

  _testMapWidgets(
    'device heartbeat cannot resurrect stale motion or rewind receive time',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      final receiveTime = h.clock;
      h.clock = h.clock.add(const Duration(minutes: 3));
      socket.event('devicestatus:update', {
        'imei': 'imei-1',
        'status': 'CONNECTED',
        'lastSeenAt': h.clock.toIso8601String(),
        'updatedAt': h.clock.toIso8601String(),
      });
      await _flush(tester);
      expect(
        h.controller.state.telemetry.vehicles.single.serverTime,
        receiveTime,
      );
      expect(h.controller.state.telemetry.stopCount, 1);
    },
  );

  _testMapWidgets(
    'pending stop expires without packets and old motion events are ignored',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      socket.event('telemetry:update', _packet(h.clock, speed: 0));
      socket.event('devicestatus:update', {
        'imei': 'imei-1',
        'motionState': 'running',
        'pendingMotionState': 'stop',
        'pendingMotionStateSince': h.clock.toIso8601String(),
        'updatedAt': h.clock.toIso8601String(),
      });
      await _flush(tester);
      expect(h.controller.state.telemetry.runningCount, 1);
      h.service.rows = [_record('1', h.clock, speed: 0)];
      h.clock = h.clock.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 5));
      expect(h.controller.state.telemetry.stopCount, 1);
      socket.event('devicestatus:update', {
        'imei': 'imei-1',
        'motionState': 'running',
        'pendingMotionState': 'stop',
        'pendingMotionStateSince': h.clock.toIso8601String(),
        'updatedAt':
            h.clock.subtract(const Duration(minutes: 1)).toIso8601String(),
      });
      await _flush(tester);
      expect(h.controller.state.telemetry.stopCount, 1);
    },
  );

  _testMapWidgets(
    'a refresh preserves newer in-flight socket data and applies scoped membership',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      final request = Completer<LiveMapTelemetry>();
      h.service.pending = request;
      final refresh = h.controller.refreshTelemetry();
      final oldClock = h.clock;
      h.clock = h.clock.add(const Duration(seconds: 2));
      socket.event('telemetry:update', _packet(h.clock, speed: 0));
      request.complete(
        h.service.parseMapTelemetryPayload([
          _record('1', oldClock, speed: 32),
          _record('2', oldClock, speed: 32),
        ]),
      );
      await refresh;
      await _flush(tester);
      expect(h.controller.state.telemetry.allCount, 2);
      expect(
        h.controller.state.telemetry.vehicles
            .firstWhere((v) => v.id == '1')
            .speed,
        0,
      );
      h.service.pending = null;
      h.service.rows = [_record('2', h.clock, speed: 32)];
      await h.controller.refreshTelemetry();
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.map((v) => v.id), ['2']);
      expect(socket.disconnected, isTrue);
      socket.event('telemetry:update', _packet(h.clock, speed: 99));
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.map((v) => v.id), ['2']);
    },
  );

  _testMapWidgets(
    'initial offline load retries and closed socket is replaced without stale callbacks',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.service.fail = true;
      h.initialize();
      await _flush(tester);
      expect(h.controller.state.telemetry.allCount, 0);
      expect(h.socket.telemetry, isEmpty);
      h.service.fail = false;
      h.clock = h.clock.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 5));
      await _flush(tester);
      expect(h.controller.state.telemetry.allCount, 1);
      final old = h.socket.telemetry.single..connect();
      old.drop();
      h.clock = h.clock.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 5));
      await _flush(tester);
      expect(old.disconnected, isTrue);
      expect(h.socket.telemetry, hasLength(2));
      h.socket.telemetry.last.connect();
      old.event(
        'telemetry:update',
        _packet(h.clock.add(const Duration(seconds: 2)), speed: 0),
      );
      old.drop();
      await _flush(tester);
      expect(h.controller.state.isTelemetryConnected, isTrue);
      expect(h.controller.state.telemetry.vehicles.single.speed, 32);
    },
  );

  _testMapWidgets(
    'failed refresh retains the complete previous baseline and disposed request cannot publish',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      h.service.fail = true;
      await h.controller.refreshTelemetry();
      expect(h.controller.state.telemetry.allCount, 1);
      expect(h.controller.state.errorMessage, contains('offline'));
      h.service.fail = false;
      final pending = Completer<LiveMapTelemetry>();
      h.service.pending = pending;
      final refresh = h.controller.refreshTelemetry();
      h.controller.dispose();
      pending.complete(
        h.service.parseMapTelemetryPayload([_record('2', h.clock)]),
      );
      await refresh;
      expect(h.socket.telemetry.single.disconnected, isTrue);
    },
  );

  _testMapWidgets(
    'selected subscription snapshot fills missing REST position and reconnect catches latest fix',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.service.rows = [
        {..._record('1', h.clock), 'telemetry': null},
      ];
      h.initialize();
      await _flush(tester);
      expect(
        h.controller.state.telemetry.vehicles.single.hasValidLocation,
        isFalse,
      );
      final socket = h.socket.telemetry.single..connect();
      final firstFixTime = h.clock.add(const Duration(seconds: 1));
      socket.event('telemetry:snapshot', [
        {..._packet(firstFixTime), 'vehicleId': 1},
        {..._packet(firstFixTime), 'vehicleId': 2, 'imei': 'imei-2'},
      ]);
      await _flush(tester);
      expect(h.controller.state.telemetry.allCount, 1);
      expect(
        h.controller.state.telemetry.vehicles.single.hasValidLocation,
        isTrue,
      );
      expect(
        h.controller.state.telemetry.vehicles.single.locationServerTime,
        firstFixTime,
      );
      h.service.rows = [_record('1', firstFixTime)];
      socket.drop();
      socket.connect();
      await _flush(tester);
      final subscriptions = socket.emits.where(
        (e) => e.$1 == 'telemetry:subscribe',
      );
      expect(subscriptions, hasLength(2));
      expect(
        subscriptions.every((e) => (e.$2 as Map)['snapshot'] == true),
        isTrue,
      );
      final nextFixTime = firstFixTime.add(const Duration(seconds: 30));
      socket.event('telemetry:snapshot', [
        {..._packet(nextFixTime), 'latitude': 40.702},
      ]);
      await _flush(tester);
      final latest = h.controller.state.telemetry.vehicles.single;
      expect(latest.latitude, 40.702);
      expect(latest.locationServerTime, nextFixTime);
      socket.event('telemetry:snapshot', [_packet(firstFixTime)]);
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.latitude, 40.702);
      expect(
        h.controller.state.telemetry.vehicles.single.serverTime,
        nextFixTime,
      );
    },
  );

  for (final rejectedPosition in [false, true]) {
    _testMapWidgets(
      'new valid fix remains usable after ${rejectedPosition ? 'rejected GPS jump' : 'sparse telemetry'} advances packet time',
      (tester) async {
        final h = _Harness(
          LiveMapRoleConfig.user(),
          target: const LiveMapVehicleTarget(vehicleId: '1'),
        );
        h.initialize();
        await _flush(tester);
        final fixTime = h.clock;
        final socket = h.socket.telemetry.single..connect();
        h.clock = h.clock.add(const Duration(seconds: 30));
        socket.event('telemetry:update', {
          'imei': 'imei-1',
          'serverTime': h.clock.toIso8601String(),
          'speedKph': 32,
          if (rejectedPosition) ...{'latitude': 41.7, 'longitude': -74.0},
        });
        await _flush(tester);
        final withoutFix = h.controller.state.telemetry.vehicles.single;
        expect(withoutFix.serverTime, h.clock);
        expect(withoutFix.latitude, 40.7);
        expect(withoutFix.locationServerTime, fixTime);
        h.clock = h.clock.add(const Duration(seconds: 2));
        socket.event('telemetry:update', {
          ..._packet(h.clock),
          'latitude': 40.702,
        });
        await _flush(tester);
        final moved = h.controller.state.telemetry.vehicles.single;
        expect(moved.latitude, 40.702);
        expect(moved.locationServerTime, h.clock);
      },
    );
  }

  _testMapWidgets(
    'delayed newer GPS fix merges position without regressing newer nonlocation packet metadata',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.initialize();
      await _flush(tester);
      final initialFixTime = h.clock;
      final socket = h.socket.telemetry.single..connect();
      final metadataTime = initialFixTime.add(const Duration(seconds: 60));
      socket.event('telemetry:update', {
        'imei': 'imei-1',
        'serverTime': metadataTime.toIso8601String(),
        'deviceTime': metadataTime.toIso8601String(),
        'speedKph': 70,
        'odometer': 700,
        'ignition': false,
      });
      await _flush(tester);
      final beforeFix = h.controller.state.telemetry.vehicles.single;
      expect(beforeFix.locationServerTime, initialFixTime);
      final delayedFixTime = initialFixTime.add(const Duration(seconds: 5));
      socket.event('telemetry:update', {
        ..._packet(delayedFixTime, speed: 0),
        'latitude': 40.701,
        'name': 'Older name',
        'odometer': 1,
        'ignition': true,
      });
      await _flush(tester);
      final acceptedFix = h.controller.state.telemetry.vehicles.single;
      expect(acceptedFix.latitude, 40.701);
      expect(acceptedFix.locationServerTime, delayedFixTime);
      expect(acceptedFix.serverTime, metadataTime);
      expect(acceptedFix.deviceTime, metadataTime);
      expect(acceptedFix.updatedAt, metadataTime);
      expect(acceptedFix.speed, 70);
      expect(acceptedFix.odometerKm, 700);
      expect(acceptedFix.ignition, isFalse);
      expect(acceptedFix.name, 'Vehicle 1');
      final stationaryFixTime = initialFixTime.add(const Duration(seconds: 10));
      socket.event('telemetry:update', {
        ..._packet(stationaryFixTime, speed: 0),
        'latitude': 40.701,
      });
      await _flush(tester);
      expect(
        h.controller.state.telemetry.vehicles.single.locationServerTime,
        stationaryFixTime,
      );
      socket.event('telemetry:update', {
        ..._packet(initialFixTime.add(const Duration(seconds: 3)), speed: 99),
        'latitude': 40.7005,
      });
      await _flush(tester);
      final latest = h.controller.state.telemetry.vehicles.single;
      expect(latest.latitude, 40.701);
      expect(latest.locationServerTime, stationaryFixTime);
      expect(latest.serverTime, metadataTime);
      expect(latest.speed, 70);
    },
  );

  _testMapWidgets(
    'sparse newer HTTP refresh retains authorized last fix and its original time',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.initialize();
      await _flush(tester);
      final fixTime = h.clock;
      final socket = h.socket.telemetry.single..connect();
      h.clock = h.clock.add(const Duration(seconds: 30));
      h.service.rows = [
        {
          'vehicleId': '1',
          'imei': 'imei-1',
          'telemetry': {
            'serverTime': h.clock.toIso8601String(),
            'speedKph': 32,
          },
        },
      ];
      await h.controller.refreshTelemetry();
      final retained = h.controller.state.telemetry.vehicles.single;
      expect(retained.latitude, 40.7);
      expect(retained.hasValidLocation, isTrue);
      expect(retained.serverTime, h.clock);
      expect(retained.locationServerTime, fixTime);
      h.clock = h.clock.add(const Duration(seconds: 2));
      socket.event('telemetry:update', {
        ..._packet(h.clock),
        'latitude': 40.702,
      });
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.latitude, 40.702);
    },
  );

  _testMapWidgets(
    'invalid GPS flags cannot move the marker or advance fix time',
    (tester) async {
      final h = _Harness(LiveMapRoleConfig.user());
      h.initialize();
      await _flush(tester);
      final fixTime = h.clock;
      final socket = h.socket.telemetry.single..connect();
      for (final invalid in [
        {'valid': false},
        {'satellites': 2},
      ]) {
        h.clock = h.clock.add(const Duration(seconds: 30));
        socket.event('telemetry:update', {
          ..._packet(h.clock),
          'latitude': 40.702,
          ...invalid,
        });
        await _flush(tester);
        final latest = h.controller.state.telemetry.vehicles.single;
        expect(latest.latitude, 40.7);
        expect(latest.locationServerTime, fixTime);
      }
    },
  );

  _testMapWidgets(
    'selected device packet with contradictory vehicle ID cannot patch authorized row',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      h.clock = h.clock.add(const Duration(seconds: 30));
      socket.event('telemetry:update', {
        ..._packet(h.clock, speed: 99),
        'vehicleId': 999,
        'latitude': 40.702,
      });
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.speed, 32);
      expect(h.controller.state.telemetry.vehicles.single.latitude, 40.7);
    },
  );

  _testMapWidgets(
    'service expiry clears retained location and closes selected sockets',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      h.clock = h.clock.add(const Duration(seconds: 30));
      h.service.rows = [
        {
          ..._record('1', h.clock),
          'serviceBlocked': true,
          'service': {'liveAllowed': false},
        },
      ];
      await h.controller.refreshTelemetry();
      final blocked = h.controller.state.telemetry.vehicles.single;
      expect(blocked.serviceBlocked, isTrue);
      expect(blocked.hasValidLocation, isFalse);
      expect(h.controller.state.telemetry.inactiveCount, 1);
      expect(h.controller.state.isTelemetryConnected, isFalse);
      expect(socket.disconnected, isTrue);
      socket.event('telemetry:update', {
        ..._packet(h.clock),
        'latitude': 40.702,
      });
      await _flush(tester);
      expect(
        h.controller.state.telemetry.vehicles.single.hasValidLocation,
        isFalse,
      );
      expect(h.socket.telemetry, hasLength(1));
    },
  );

  _testMapWidgets(
    'rejected selected room revalidates once and waits for maintenance instead of spinning',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      socket.event('telemetry:subscribe:ack', {
        'acceptedCount': 0,
        'rejectedCount': 1,
      });
      await _flush(tester);
      expect(h.service.calls, 2);
      socket.event('telemetry:subscribe:ack', {
        'acceptedCount': 0,
        'rejectedCount': 1,
      });
      await _flush(tester);
      expect(h.service.calls, 2);
      expect(h.controller.state.isTelemetryConnected, isFalse);
      expect(
        h.controller.state.errorMessage,
        contains('Live tracking is unavailable'),
      );
      socket.event('telemetry:subscribe:ack', {
        'acceptedCount': 1,
        'rejectedCount': 0,
      });
      expect(h.controller.state.isTelemetryConnected, isTrue);
      expect(h.controller.state.errorMessage, isNull);
    },
  );

  _testMapWidgets(
    'selected binding event refreshes after an in-flight baseline and switches to new device',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.initialize();
      await _flush(tester);
      final socket = h.socket.telemetry.single..connect();
      final oldRequest = Completer<LiveMapTelemetry>();
      h.service.pending = oldRequest;
      final refresh = h.controller.refreshTelemetry();
      socket.event('vehicle:device-changed', {
        'vehicleId': 1,
        'oldImei': 'imei-1',
        'newImei': 'replacement',
      });
      h.service.rows = [
        {..._record('1', h.clock), 'imei': 'replacement', 'telemetry': null},
      ];
      h.service.pending = null;
      oldRequest.complete(
        h.service.parseMapTelemetryPayload([_record('1', h.clock)]),
      );
      await refresh;
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.imei, 'replacement');
      expect(
        h.controller.state.telemetry.vehicles.single.hasValidLocation,
        isFalse,
      );
      expect(socket.disconnected, isTrue);
      final replacement = h.socket.telemetry.last..connect();
      expect((replacement.emits.last.$2 as Map)['imeis'], ['replacement']);
      h.clock = h.clock.add(const Duration(seconds: 30));
      replacement.event('telemetry:snapshot', [
        {..._packet(h.clock), 'imei': 'replacement', 'latitude': 40.702},
      ]);
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.latitude, 40.702);
      final beforeUnrelated = h.service.calls;
      replacement.event('vehicle:device-changed', {
        'vehicleId': 999,
        'oldImei': 'foreign',
        'newImei': 'other',
      });
      await _flush(tester);
      expect(h.service.calls, beforeUnrelated);
    },
  );

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user(),
    LiveMapRoleConfig.demo(),
  ]) {
    _testMapWidgets(
      '${config.telemetryNamespace}/${config.role.name}: selected vehicle owns telemetry, alerts and subscriptions',
      (tester) async {
        final h = _Harness(
          config,
          target: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-1'),
        );
        h.service.rows = List.generate(3, (i) => _record('${i + 1}', h.clock));
        h.service.events = [_alert(1, 'imei-1'), _alert(2, 'imei-2')];
        h.initialize();
        await _flush(tester);
        expect(h.controller.state.telemetry.allCount, 1);
        expect(h.controller.state.telemetry.vehicles.single.id, '2');
        expect(h.controller.state.telemetry.runningCount, 1);
        expect(h.events.calls, 0);
        expect(h.service.eventImeis, ['imei-2']);
        expect(h.controller.state.alerts.map((event) => event.id), [2]);
        final telemetry = h.socket.telemetry.single..connect();
        final subscription = telemetry.emits
            .singleWhere((event) => event.$1 == 'telemetry:subscribe')
            .$2 as Map;
        expect(subscription['scope'], isNull);
        expect(subscription['imeis'], ['imei-2']);
        if (config.telemetrySubscribeMode !=
            LiveMapTelemetrySubscribeMode.demoScope) {
          expect(subscription['snapshot'], isTrue);
          expect(subscription['delivery'], 'immediate');
        }
        h.clock = h.clock.add(const Duration(seconds: 1));
        telemetry.event('telemetry:update:batch', {
          'records': List.generate(
            3,
            (i) => {..._packet(h.clock, speed: 0), 'imei': 'imei-${i + 1}'},
          ),
        });
        await _flush(tester);
        expect(h.controller.state.telemetry.vehicles.single.id, '2');
        expect(h.controller.state.telemetry.stopCount, 1);
        if (config.notificationNamespace != null) {
          final notifications = h.socket.notifications.single..connect();
          final notificationSubscription = notifications.emits
              .singleWhere((event) => event.$1 == 'notif:subscribe')
              .$2 as Map;
          expect(notificationSubscription, {
            'imeis': ['imei-2'],
          });
          notifications.event('notif:new', {
            'id': 3,
            'imei': 'imei-1',
            'title': 'Other',
          });
          notifications.event('notif:new', {'id': 4, 'title': 'Unscoped'});
          notifications.event('notif:new', {
            'id': 5,
            'imei': 'imei-2',
            'title': 'Selected',
          });
          expect(h.controller.state.alerts.map((event) => event.id).toSet(), {
            2,
            5,
          });
        }
      },
    );
  }

  _testMapWidgets(
    'missing target never falls back to the fleet or socket scopes',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.superadmin(),
        target: const LiveMapVehicleTarget(
          vehicleId: 'missing',
          imei: 'imei-1',
        ),
      );
      h.initialize();
      await _flush(tester);
      expect(h.controller.state.telemetry.allCount, 0);
      expect(h.controller.state.alerts, isEmpty);
      expect(
        h.controller.state.errorMessage,
        'This vehicle is unavailable or no longer assigned to your account.',
      );
      expect(h.socket.telemetry, isEmpty);
      expect(h.socket.notifications, isEmpty);
      expect(h.events.calls, 0);
      expect(h.service.eventImeis, isEmpty);
    },
  );

  _testMapWidgets(
    'failed selected baseline stays a network error until a successful retry',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: 'missing'),
      );
      h.service.fail = true;
      h.initialize();
      await _flush(tester);
      expect(h.controller.state.errorMessage, contains('offline'));
      expect(h.controller.state.isAlertsLoading, isFalse);
      h.service.fail = false;
      await h.controller.refreshTelemetry();
      expect(h.controller.state.errorMessage, contains('no longer assigned'));
      h.service.fail = true;
      await h.controller.refreshTelemetry();
      await tester.pump(const Duration(seconds: 5));
      expect(h.controller.state.errorMessage, contains('offline'));
      expect(h.controller.state.telemetry.allCount, 0);
      h.service.fail = false;
      await h.controller.refreshTelemetry();
      expect(h.controller.state.errorMessage, contains('no longer assigned'));
    },
  );

  _testMapWidgets(
    'IMEI fallback only applies when the target has no vehicle ID',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.user(),
        target: const LiveMapVehicleTarget(vehicleId: '', imei: ' IMEI-1 '),
      );
      h.service.rows.add(_record('2', h.clock));
      h.initialize();
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.id, '1');
    },
  );

  _testMapWidgets(
    'selected vehicle without IMEI remains selected and opens no fleet subscriptions',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.superadmin(),
        target: const LiveMapVehicleTarget(vehicleId: '1'),
      );
      h.service.rows = [
        {..._record('1', h.clock, inactive: true), 'imei': ''},
        _record('2', h.clock),
      ];
      h.initialize();
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.id, '1');
      expect(h.controller.state.telemetry.allCount, 1);
      expect(h.controller.state.telemetry.inactiveCount, 1);
      expect(h.socket.telemetry, isEmpty);
      expect(h.socket.notifications, isEmpty);
      expect(h.controller.state.isAlertsLoading, isFalse);
    },
  );

  _testMapWidgets(
    'revoked selected vehicle cannot be replaced by a different vehicle using its IMEI',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.superadmin(),
        target: const LiveMapVehicleTarget(vehicleId: '1', imei: 'imei-1'),
      );
      h.service.events = [_alert(1, 'imei-1')];
      h.initialize();
      await _flush(tester);
      final old = h.socket.telemetry.single..connect();
      h.socket.notifications.single.connect();
      h.service.rows = [
        {..._record('2', h.clock), 'imei': 'imei-1'},
      ];
      await h.controller.refreshTelemetry();
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles, isEmpty);
      expect(h.controller.state.alerts, isEmpty);
      expect(h.controller.state.errorMessage, contains('no longer assigned'));
      expect(old.disconnected, isTrue);
      expect(h.socket.telemetry, hasLength(1));
      old.event('telemetry:update', _packet(h.clock, speed: 90));
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles, isEmpty);
    },
  );

  _testMapWidgets(
    'selected vehicle device replacement drops old live state and subscribes its new IMEI',
    (tester) async {
      final h = _Harness(
        LiveMapRoleConfig.admin(),
        target: const LiveMapVehicleTarget(vehicleId: '1', imei: 'imei-1'),
      );
      h.initialize();
      await _flush(tester);
      final old = h.socket.telemetry.single..connect();
      old.event(
        'telemetry:update',
        _packet(h.clock.add(const Duration(seconds: 30)), speed: 90),
      );
      await _flush(tester);
      h.service.rows = [
        {
          ..._record('1', h.clock),
          'imei': 'imei-new',
          'telemetry': {
            'imei': 'imei-new',
            'serverTime': h.clock.toIso8601String(),
            'latitude': 40.7,
            'longitude': -74.0,
            'speedKph': 10,
          },
        },
        _record('2', h.clock),
      ];
      await h.controller.refreshTelemetry();
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.imei, 'imei-new');
      expect(h.controller.state.telemetry.vehicles.single.speed, 10);
      expect(old.disconnected, isTrue);
      final current = h.socket.telemetry.last..connect();
      final subscription = current.emits
          .singleWhere((e) => e.$1 == 'telemetry:subscribe')
          .$2 as Map;
      expect(subscription['imeis'], ['imei-new']);
      current.event('telemetry:update', {
        ..._packet(h.clock.add(const Duration(seconds: 60)), speed: 99),
        'vehicleId': '1',
      });
      current.event('devicestatus:update', {
        'vehicleId': '1',
        'imei': 'imei-1',
        'status': 'DISCONNECTED',
      });
      await _flush(tester);
      expect(h.controller.state.telemetry.vehicles.single.imei, 'imei-new');
      expect(h.controller.state.telemetry.vehicles.single.speed, 10);
      expect(h.service.eventImeis, contains('imei-new'));
    },
  );
}

// Map routes can stay mounted underneath another route. Verify that their
// sockets and requests stop, including late completions from the old visit.
void requestLifecycleTests() {
  _testMapWidgets('covering the map releases sockets and ignores old packets',
      (tester) async {
    final h = _Harness(LiveMapRoleConfig.superadmin());
    h.initialize();
    await _flush(tester);
    final old = h.socket.telemetry.single..connect();
    final notifications = h.socket.notifications.single..connect();
    final before = h.controller.state.telemetry.vehicles.single;
    h.controller.setScreenVisible(false);
    expect(old.disconnected, isTrue);
    expect(notifications.disconnected, isTrue);
    old.event('telemetry:update',
        _packet(h.clock.add(const Duration(seconds: 1)), speed: 99));
    final calls = h.service.calls;
    h.clock = h.clock.add(const Duration(minutes: 2));
    await tester.pump(const Duration(minutes: 2));
    expect(h.service.calls, calls);
    expect(h.controller.state.telemetry.vehicles.single, same(before));
    h.controller.setScreenVisible(true);
    await _flush(tester);
    expect(h.service.calls, calls + 1);
    expect(h.socket.telemetry, hasLength(2));
  });

  _testMapWidgets(
      'a cancelled hidden baseline cannot overwrite a resumed baseline',
      (tester) async {
    final h = _Harness(LiveMapRoleConfig.user());
    h.service.pending = Completer<LiveMapTelemetry>();
    h.initialize();
    await _flush(tester);
    final oldToken = h.service.tokens.single;
    final oldResult = h.service.pending!;
    h.controller.setScreenVisible(false);
    expect(oldToken!.isCancelled, isTrue);
    h.service.pending = null;
    h.service.rows = [_record('2', h.clock)];
    h.controller.setScreenVisible(true);
    await _flush(tester);
    expect(h.controller.state.telemetry.vehicles.single.id, '2');
    oldResult
        .complete(h.service.parseMapTelemetryPayload([_record('1', h.clock)]));
    await _flush(tester);
    expect(h.controller.state.telemetry.vehicles.single.id, '2');
    expect(h.socket.telemetry, hasLength(1));
  });

  _testMapWidgets(
      'Superadmin fleet joins explicit authorized batches without a global room',
      (tester) async {
    final h = _Harness(LiveMapRoleConfig.superadmin());
    h.service.rows = List.generate(501, (i) => _record('${i + 1}', h.clock));
    h.initialize();
    await _flush(tester);
    final socket = h.socket.telemetry.single..connect();
    final subscriptions = socket.emits
        .where((e) => e.$1 == 'telemetry:subscribe')
        .map((e) => e.$2 as Map)
        .toList();
    expect(subscriptions.single['imeis'], hasLength(501));
    expect(subscriptions.single['delivery'], 'batch');
    expect(subscriptions.single['snapshot'], isFalse);
    expect(subscriptions.single.containsKey('scope'), isFalse);
  });
}

AppNotification _alert(int id, String imei) => AppNotification(
      id: id,
      title: 'Alert $id',
      message: 'Vehicle alert',
      isRead: false,
      vehicleImei: imei,
    );

Map<String, dynamic> _record(
  String id,
  DateTime clock, {
  double speed = 32,
  bool inactive = false,
}) =>
    {
      'vehicleId': id,
      'vehicleName': 'Vehicle $id',
      'imei': 'imei-$id',
      'status': inactive ? 'inactive' : 'running',
      'telemetry': inactive
          ? null
          : {
              'imei': 'imei-$id',
              'serverTime': clock.toIso8601String(),
              'deviceTime':
                  clock.subtract(const Duration(seconds: 10)).toIso8601String(),
              'latitude': 40.7,
              'longitude': -74.0,
              'speedKph': speed,
              'ignition': true,
            },
    };
Map<String, dynamic> _packet(DateTime clock, {double speed = 32}) => {
      'imei': 'imei-1',
      'serverTime': clock.toIso8601String(),
      'deviceTime':
          clock.subtract(const Duration(seconds: 10)).toIso8601String(),
      'latitude': 40.7,
      'longitude': -74.0,
      'speedKph': speed,
    };
Dio _dio(dynamic Function(RequestOptions) reply) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (request, handler) {
        try {
          handler.resolve(
            Response<dynamic>(
              requestOptions: request,
              statusCode: 200,
              data: {'action': true, 'data': reply(request)},
            ),
          );
        } catch (error) {
          handler.reject(DioException(requestOptions: request, error: error));
        }
      },
    ),
  );
  return dio;
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 125));
  await tester.pump();
}

class _Harness {
  _Harness(this.config, {LiveMapVehicleTarget? target}) {
    service = _FleetService(config, [_record('1', clock)]);
    socket = _SocketService();
    events = _EventsService(config);
    controller = LiveMapController(
      vehicleService: service,
      mapEventsService: events,
      socketService: socket,
      config: config,
      vehicleTarget: target,
      now: () => clock,
    );
    _activeControllers.add(controller);
  }
  final LiveMapRoleConfig config;
  DateTime clock = DateTime.now().toUtc();
  late final _FleetService service;
  late final _SocketService socket;
  late final _EventsService events;
  late final LiveMapController controller;
  void initialize() => controller.initialize();
}

class _FleetService extends LiveMapVehicleService {
  _FleetService(LiveMapRoleConfig config, this.rows)
      : super(apiClient: ApiClient(Dio()), config: config);
  List<dynamic> rows;
  Completer<LiveMapTelemetry>? pending;
  int calls = 0;
  bool fail = false;
  List<AppNotification> events = [];
  final eventImeis = <String>[];
  final tokens = <CancelToken?>[];
  @override
  Future<LiveMapVehicleEventPage> getVehicleEventsByImei(
    String imei, {
    int limit = 50,
    String? beforeId,
    String? from,
    String? to,
    String? source,
    String? severity,
    CancelToken? cancelToken,
  }) async {
    eventImeis.add(imei);
    return LiveMapVehicleEventPage(items: events);
  }

  @override
  Future<LiveMapTelemetry> getMapTelemetry(
      {String? refreshKey,
      CancelToken? cancelToken,
      LiveMapVehicleTarget? target}) async {
    calls++;
    tokens.add(cancelToken);
    if (fail) throw StateError('offline');
    if (pending != null) return pending!.future;
    return parseMapTelemetryPayload(rows);
  }
}

class _EventsService extends LiveMapEventsService {
  _EventsService(LiveMapRoleConfig config)
      : super(apiClient: ApiClient(Dio()), config: config);
  int calls = 0;
  @override
  Future<NotificationPage> getMapEvents({
    int limit = 50,
    String? beforeId,
    String? from,
    String? to,
    String? source,
    String? severity,
    CancelToken? cancelToken,
  }) async {
    calls++;
    return const NotificationPage(items: [], hasMore: false, unreadCount: 0);
  }
}

class _SocketService extends SocketService {
  _SocketService()
      : super(
          TokenStorage(const FlutterSecureStorage()),
          apiBaseUrl: 'https://example.test/api',
        );
  final telemetry = <_Connection>[];
  final notifications = <_Connection>[];
  @override
  Future<SocketConnection> connect(
    String namespace, {
    bool authenticated = true,
  }) async {
    final connection = _Connection();
    if (namespace == '/telemetry' || namespace == '/demo-telemetry') {
      telemetry.add(connection);
    }
    if (namespace == '/notifications') notifications.add(connection);
    return connection;
  }
}

class _Connection implements SocketConnection {
  final handlers = <String, List<SocketEventHandler>>{};
  final connects = <void Function()>[];
  final disconnects = <SocketEventHandler>[];
  final emits = <(String, dynamic)>[];
  bool disconnected = false;
  @override
  bool isConnected = false;
  @override
  void emit(String name, [dynamic data]) => emits.add((name, data));
  @override
  void on(String name, SocketEventHandler callback) =>
      handlers.putIfAbsent(name, () => []).add(callback);
  @override
  void off(String name, [SocketEventHandler? callback]) {
    if (callback == null) {
      handlers.remove(name);
    } else {
      handlers[name]?.remove(callback);
    }
  }

  @override
  void onConnect(void Function() callback) => connects.add(callback);
  @override
  void onDisconnect(SocketEventHandler callback) => disconnects.add(callback);
  @override
  void onError(SocketEventHandler callback) {}
  @override
  void disconnect() {
    disconnected = true;
    drop();
  }

  void connect() {
    isConnected = true;
    for (final callback in connects) {
      callback();
    }
  }

  void drop() {
    isConnected = false;
    for (final callback in disconnects) {
      callback('disconnect');
    }
  }

  void event(String name, dynamic data) {
    for (final callback in handlers[name] ?? <SocketEventHandler>[]) {
      callback(data);
    }
  }
}

final _activeControllers = <LiveMapController>[];
void _testMapWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final controller in _activeControllers) {
        if (controller.mounted) controller.dispose();
      }
      _activeControllers.clear();
      await tester.pump();
    }
  });
}
