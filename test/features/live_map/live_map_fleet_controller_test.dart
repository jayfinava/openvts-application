import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/socket/socket_service.dart';
import 'package:open_vts/core/storage/token_storage.dart';
import 'package:open_vts/features/live_map/controllers/live_map_fleet_controller.dart';
import 'package:open_vts/features/live_map/models/live_map_role_config.dart';
import 'package:open_vts/features/live_map/services/live_map_events_service.dart';
import 'package:open_vts/features/live_map/services/live_map_fleet_service.dart';
import 'package:open_vts/features/live_map/services/live_map_vehicle_service.dart';

import 'fleet_wire_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user()
  ]) {
    _testWidgets(
        '${config.role.name}: viewport stream never downloads the full fleet',
        (tester) async {
      final harness = _Harness(config);
      addTearDown(harness.dispose);
      await harness.start(tester);
      expect(harness.sockets.namespaces, ['/map-v2']);
      expect(harness.requests, isEmpty);
      harness.scene(total: 20000);
      await tester.pump(const Duration(milliseconds: 130));
      expect(harness.controller.state.telemetry.allCount, 20000);
      expect(harness.controller.state.telemetry.vehicles, hasLength(1));
      for (var i = 0; i < 100; i++) {
        harness.controller.setViewport([70, 20, 71 + i / 100, 21], 12);
      }
      await tester.pump(const Duration(milliseconds: 130));
      expect(harness.socket.emitted.where((m) => m.$1 == 'map:set-interest'),
          hasLength(2));
      expect(harness.requests, isEmpty);
    });
  }

  _testWidgets(
      'directory search is scoped, paged, and retains only the current page',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    await _flush(tester);
    expect(harness.controller.state.fleet!.directory, hasLength(100));
    expect(harness.requests.single.uri.path, '/api/map/v2/vehicles');
    expect(harness.requests.single.queryParameters['limit'], 100);
    final nextPage = harness.controller.loadDirectoryPage();
    await _flush(tester);
    await nextPage;
    expect(harness.controller.state.fleet!.page.start, 100);
    expect(harness.controller.state.fleet!.directory.first.id, '101');
    expect(harness.controller.state.fleet!.directory, hasLength(100));
    harness.controller
        .setFleetQuery(search: 'vehicle-19999', status: 'running');
    await _flush(tester);
    await _flush(tester);
    expect(harness.requests.last.queryParameters['search'], 'vehicle-19999');
    expect(harness.requests.last.queryParameters['status'], 'running');
    expect(
        harness.requests.last.queryParameters.containsKey('cursor'), isFalse);
  });

  _testWidgets(
      'only visible rows request metrics, stale bindings cannot enrich them',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.admin());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    await _flush(tester);
    harness.controller.setVisibleRowIds(['1', '2', '3', '99999']);
    await tester.pump(const Duration(milliseconds: 210));
    await _flush(tester);
    final requests =
        harness.requests.where((r) => r.uri.path.endsWith('/metrics'));
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['ids'], '1,2,3');
    expect(harness.controller.state.fleet!.directory.first.distanceKm, isNull);
    harness.controller.setVisibleRowIds(['2', '3']);
    await tester.pump(const Duration(milliseconds: 210));
    await _flush(tester);
    expect(harness.requests.where((r) => r.uri.path.endsWith('/metrics')),
        hasLength(1));
  });

  _testWidgets(
      'unchanged summaries reuse vehicle models and service expiry clears positions',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    await harness.start(tester);
    harness.scene();
    await tester.pump(const Duration(milliseconds: 130));
    final original = harness.controller.state.telemetry.vehicles.single;
    harness.socket.event('map:summary', fleetSummary());
    await tester.pump(const Duration(milliseconds: 130));
    expect(harness.controller.state.telemetry.vehicles.single, same(original));
    final expired = fleetWireVehicle(1, revision: 2, now: harness.now)
      ..['serviceLiveUntil'] =
          harness.now.add(const Duration(seconds: 1)).toUtc().toIso8601String();
    harness.socket.event('map:state', {
      ...harness.envelope,
      'sequence': 1,
      'states': [expired],
      'removeIds': []
    });
    await tester.pump(const Duration(milliseconds: 130));
    harness.now = harness.now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(harness.controller.state.telemetry.vehicles.single.hasValidLocation,
        isFalse);
    expect(harness.controller.state.telemetry.vehicles.single.serviceBlocked,
        isTrue);
  });

  _testWidgets('metadata-only directory rows do not request telemetry metrics',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.admin());
    harness.metadataOnly = true;
    await harness.start(tester);
    harness.scene();
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    harness.controller.setVisibleRowIds(['1', '2']);
    await tester.pump(const Duration(milliseconds: 210));
    await _flush(tester);
    expect(harness.requests.where((r) => r.uri.path.endsWith('/metrics')),
        isEmpty);
    expect(
        harness.controller.state.fleet!.directory
            .every((v) => !v.hasValidLocation),
        isTrue);
  });

  _testWidgets(
      'explicit null states and removals clear HTTP directory positions',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    await _flush(tester);
    harness.socket.event('map:state', {
      ...harness.envelope,
      'sequence': 1,
      'states': [
        fleetWireVehicle(1, revision: 2)
          ..['latitude'] = null
          ..['longitude'] = null
      ],
      'removeIds': []
    });
    await tester.pump(const Duration(milliseconds: 130));
    expect(harness.controller.state.fleet!.directory.first.hasValidLocation,
        isFalse);
    harness.socket.event('map:state', {
      ...harness.envelope,
      'sequence': 2,
      'states': [],
      'removeIds': [2]
    });
    await tester.pump(const Duration(milliseconds: 130));
    expect(
        harness.controller.state.fleet!.directory[1].hasValidLocation, isFalse);
  });

  _testWidgets(
      'hidden and disposed maps cancel requests and release their namespace',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    harness.holdDirectory = true;
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    final request = harness.requests.single;
    harness.controller.setScreenVisible(false);
    expect(request.cancelToken!.isCancelled, isTrue);
    expect(harness.socket.disposed, isTrue);
    expect(harness.controller.state.telemetry.vehicles, isEmpty);
    final requests = harness.requests.length;
    await tester.pump(const Duration(minutes: 2));
    expect(harness.requests, hasLength(requests));
    harness.controller.setScreenVisible(true);
    await _flush(tester);
    expect(harness.sockets.connections, hasLength(2));
  });

  _testWidgets(
      'changed device binding never falls back to old directory coordinates',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    await harness.start(tester);
    harness.scene();
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    await _flush(tester);
    harness.socket.event('map:state', {
      ...harness.envelope,
      'sequence': 1,
      'states': [fleetWireVehicle(1, revision: 2)..['bindingVersion'] = 2],
      'removeIds': []
    });
    await tester.pump(const Duration(milliseconds: 130));
    expect(harness.controller.state.fleet!.directory.first.hasValidLocation,
        isFalse);
    expect(harness.controller.state.telemetry.vehicles.single.hasValidLocation,
        isFalse);
  });

  _testWidgets(
      'retry exhaustion disposes the reconnecting socket until manual retry',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    await harness.start(tester);
    for (var retry = 0; retry < 7; retry++) {
      harness.sockets.connections.last.event('map:error', {'code': 'capacity'});
      if (retry < 6) {
        await tester.pump(Duration(seconds: (1 << retry).clamp(0, 30)));
        await _flush(tester);
        harness.sockets.connections.last.connect();
      }
    }
    expect(harness.sockets.connections, hasLength(7));
    expect(harness.sockets.connections.last.disposed, isTrue);
    await tester.pump(const Duration(minutes: 2));
    expect(harness.sockets.connections, hasLength(7));
    await harness.controller.refreshTelemetry();
    await _flush(tester);
    expect(harness.sockets.connections, hasLength(8));
  });

  _testWidgets(
      'expired directory cursor recovers the visible page with a bounded locate anchor',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    await harness.start(tester);
    harness.scene();
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    final next = harness.controller.loadDirectoryPage();
    await _flush(tester);
    await next;
    expect(harness.controller.state.fleet!.page.start, 100);
    harness.expireNextCursor = true;
    final before = harness.requests.length;
    final refresh = harness.controller.refreshDirectory();
    await _flush(tester);
    await _flush(tester);
    await refresh;
    expect(harness.controller.state.fleet!.page.start, 100);
    expect(harness.controller.state.fleet!.directory.first.id, '101');
    expect(harness.requests.skip(before).map((r) => r.uri.path), [
      '/api/map/v2/vehicles',
      '/api/map/v2/vehicles/101',
      '/api/map/v2/vehicles',
      '/api/map/v2/vehicles'
    ]);
  });

  _testWidgets('terminal authorization reset clears data and never retries',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.admin());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    await tester.pump(const Duration(milliseconds: 130));
    harness.socket
        .event('map:reset', {'reason': 'session-revoked', 'retryable': false});
    expect(harness.controller.state.telemetry.vehicles, isEmpty);
    await tester.pump(const Duration(minutes: 1));
    await harness.controller.refreshTelemetry();
    expect(harness.sockets.connections, hasLength(1));
    expect(harness.socket.disposed, isTrue);
  });

  _testWidgets(
      'a silent stream drops live locations and retries with a bounded delay',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    await tester.pump(const Duration(milliseconds: 130));
    harness.now = harness.now.add(const Duration(seconds: 16));
    await tester.pump(const Duration(seconds: 4));
    expect(harness.controller.state.telemetry.vehicles, isEmpty);
    expect(harness.controller.state.isTelemetryConnected, isFalse);
    await tester.pump(const Duration(seconds: 1));
    await _flush(tester);
    expect(harness.sockets.connections, hasLength(2));
  });

  _testWidgets('scope change cancels an in-flight page and clears old metadata',
      (tester) async {
    final harness = _Harness(LiveMapRoleConfig.user());
    addTearDown(harness.dispose);
    await harness.start(tester);
    harness.scene();
    harness.holdDirectory = true;
    harness.controller.setDirectoryVisible(true);
    await _flush(tester);
    final token = harness.requests.single.cancelToken!;
    harness.socket.event(
        'map:scope-changed', {...fleetEnvelope(), 'scopeRevision': 'changed'});
    await _flush(tester);
    expect(token.isCancelled, isTrue);
    expect(harness.controller.state.fleet!.directory, isEmpty);
    expect(harness.controller.state.telemetry.vehicles, isEmpty);
  });
}

class _Harness {
  _Harness(LiveMapRoleConfig config) {
    _activeHarnesses.add(this);
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      if (holdDirectory && request.uri.path.endsWith('/vehicles')) return;
      if (expireNextCursor && request.queryParameters['cursor'] != null) {
        expireNextCursor = false;
        handler.reject(DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: request, statusCode: 409)));
        return;
      }
      dynamic data;
      if (request.uri.path.endsWith('/metrics')) {
        data = {
          'rows': [
            {
              'vehicleId': 1,
              'imei': 'imei-1',
              'bindingVersion': 999,
              'serviceRevision': 1,
              'metricsAvailable': true,
              'telemetry': {'distanceToday': 99}
            }
          ]
        };
      } else if (RegExp(r'/vehicles/\d+$').hasMatch(request.uri.path)) {
        final id = int.parse(request.uri.path.split('/').last);
        data = {
          'row': fleetDirectoryRow(id, now: now),
          'position': id - 1,
          'anchorCursor': 'anchor',
          'queryRevision': 'query',
          'scopeRevision': 'scope'
        };
      } else {
        final cursor = request.queryParameters['cursor'];
        final offset = cursor == null || cursor == 'anchor' ? 0 : 100;
        data = {
          'rows': List.generate(
              100,
              (i) => fleetDirectoryRow(offset + i + 1, now: now)
                ..['canViewLive'] = !metadataOnly),
          'total': 20000,
          'pageStart': offset,
          'hasMore': true,
          'nextCursor': 'next-${offset + 100}',
          'previousCursor': offset == 0 ? null : 'previous',
          'queryRevision': 'query',
          'scopeRevision': 'scope'
        };
      }
      handler.resolve(Response(
          requestOptions: request,
          statusCode: 200,
          data: {'action': true, 'data': data}));
    }));
    final api = ApiClient(dio);
    controller = LiveMapFleetController(
        vehicleService: LiveMapVehicleService(apiClient: api, config: config),
        mapEventsService: LiveMapEventsService(apiClient: api, config: config),
        socketService: sockets,
        config: config,
        fleetService: LiveMapFleetService(api),
        now: () => now);
  }
  late final Dio dio;
  late final LiveMapFleetController controller;
  final sockets = _Sockets();
  final requests = <RequestOptions>[];
  DateTime now = DateTime.now();
  bool holdDirectory = false;
  bool metadataOnly = false;
  bool expireNextCursor = false;
  _Connection get socket => sockets.connections.first;
  Map<String, dynamic> get envelope => fleetEnvelope(
      interest: socket.emitted
          .lastWhere((e) => e.$1 == 'map:set-interest')
          .$2['interestRevision'] as int);
  Future<void> start(WidgetTester tester) async {
    controller.initialize();
    await _flush(tester);
    socket.connect();
    socket.event('map:open', fleetEnvelope(scene: 0, interest: 0));
  }

  void scene({int total = 5000}) {
    socket.event('map:summary', fleetSummary(total: total));
    socket.event('map:scene-start',
        {...fleetEnvelope(), 'expectedChunks': 1, 'expectedCount': 1});
    socket.event('map:scene-chunk', {
      ...fleetEnvelope(),
      'chunkIndex': 0,
      'items': [fleetWireVehicle(1, now: now)]
    });
    socket.event('map:scene-end', {...fleetEnvelope(), 'expectedCount': 1});
  }

  void dispose() {
    if (controller.mounted) controller.dispose();
    dio.close(force: true);
  }
}

class _Sockets extends SocketService {
  _Sockets()
      : super(TokenStorage(const FlutterSecureStorage()),
            apiBaseUrl: 'https://example.test/api');
  final connections = <_Connection>[];
  final namespaces = <String>[];
  @override
  Future<SocketConnection> connect(String namespace,
      {bool authenticated = true}) async {
    namespaces.add(namespace);
    final result = _Connection();
    connections.add(result);
    return result;
  }
}

class _Connection implements SocketConnection {
  final handlers = <String, SocketEventHandler>{};
  final emitted = <(String, dynamic)>[];
  void Function()? connected;
  SocketEventHandler? disconnected;
  bool disposed = false;
  @override
  bool isConnected = false;
  @override
  void emit(String event, [dynamic data]) => emitted.add((event, data));
  @override
  void on(String event, SocketEventHandler handler) =>
      handlers[event] = handler;
  @override
  void off(String event, [SocketEventHandler? handler]) =>
      handlers.remove(event);
  @override
  void onConnect(void Function() handler) => connected = handler;
  @override
  void onDisconnect(SocketEventHandler handler) => disconnected = handler;
  @override
  void onError(SocketEventHandler handler) {}
  @override
  void disconnect() {
    disposed = true;
    isConnected = false;
  }

  void connect() {
    isConnected = true;
    connected?.call();
  }

  void event(String name, dynamic data) => handlers[name]?.call(data);
}

final _activeHarnesses = <_Harness>[];
void _testWidgets(String name, Future<void> Function(WidgetTester) body) {
  testWidgets(name, (tester) async {
    try {
      await body(tester);
    } finally {
      for (final harness in _activeHarnesses) {
        harness.dispose();
      }
      _activeHarnesses.clear();
      await tester.pump();
    }
  });
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}
