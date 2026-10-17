import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/socket/socket_service.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/storage/token_storage.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/live_map/controllers/live_map_controller.dart';
import 'package:open_vts/features/live_map/controllers/live_map_providers.dart';
import 'package:open_vts/features/live_map/models/live_map_role_config.dart';
import 'package:open_vts/features/live_map/models/live_map_vehicle_target.dart';
import 'package:open_vts/features/live_map/rendering/fleet_marker_layout.dart';
import 'package:open_vts/features/live_map/screens/live_map_screen.dart';
import 'package:open_vts/features/live_map/services/live_map_events_service.dart';
import 'package:open_vts/features/live_map/services/live_map_vehicle_service.dart';
import 'package:open_vts/features/notifications/models/notification_page.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user(),
  ]) {
    testWidgets(
      '${config.role.name}: actual map keeps 5000 vehicles through dense zoom, pans and live bursts',
      (tester) async {
        await HttpOverrides.runZoned(() async {
          dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false');
          SharedPreferences.setMockInitialValues({
            config.visualSettingsStorageKey: jsonEncode({
              'cluster': false,
              'vehicleLabel': true,
              'ripple': true,
              'geofence': false,
              'poi': false,
              'route': false,
            }),
          });
          final cache = LocalCache(await SharedPreferences.getInstance());
          final harness = _FleetHarness(config);
          tester.view.reset();
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          try {
            await tester.pumpWidget(_mapApp(cache, harness));
            await _flush(tester);
            expect(find.byType(FlutterMap), findsOneWidget);
            expect(
                harness.controller.state.telemetry.vehicles, hasLength(5000));
            final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
            final camera = map.mapController!;
            final telemetrySocket = harness.socket.telemetry.single..connect();
            await _flush(tester);

            // Initial bounds fit must represent both depots without thousands
            // of Flutter marker elements, even with clustering disabled.
            expect(_fleetMarkers(tester), isNotEmpty);
            expect(_representedVehicles(tester), 5000);
            _expectBoundedMarkers(tester);

            for (var burst = 1; burst <= 12; burst++) {
              harness.clock = harness.clock.add(const Duration(seconds: 1));
              telemetrySocket.event('telemetry:update:batch', {
                'records': List.generate(5000, (index) {
                  final point = _pointFor(index, burst: burst);
                  return {
                    'imei': 'imei-$index',
                    'serverTime': harness.clock.toIso8601String(),
                    'deviceTime': harness.clock.toIso8601String(),
                    'latitude': point.latitude,
                    'longitude': point.longitude,
                    'speedKph': index.isEven ? 0 : 35,
                    'ignition': true,
                  };
                }),
              });
              await tester.pump(const Duration(milliseconds: 500));

              // A pan at the same zoom used to leave visibility unchanged.
              // Alternate depots and street zooms to exercise camera rebuilds.
              final depot = burst.isEven ? 0 : 2500;
              final center = _pointFor(depot, burst: burst);
              camera.move(center, burst <= 6 ? 17 : 19);
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 50));
              _expectBoundedMarkers(tester);
              expect(_representedVehicles(tester), 2500);
              expect(
                  harness.controller.state.telemetry.vehicles, hasLength(5000));
              expect(harness.controller.state.telemetry.runningCount, 2500);
              expect(harness.controller.state.telemetry.stopCount, 2500);
              expect(tester.takeException(), isNull);
            }

            // Panning completely away removes marker elements while all
            // offscreen vehicles remain in the live controller's fleet.
            camera.move(const LatLng(0, 0), 17);
            await tester.pump();
            expect(_fleetMarkers(tester), isEmpty);
            expect(harness.controller.state.telemetry.allCount, 5000);
            camera.move(_pointFor(0, burst: 12), 17);
            await tester.pump();
            expect(_representedVehicles(tester), 2500);
            _expectBoundedMarkers(tester);
            expect(tester.takeException(), isNull);

            if (config.role == LiveMapRole.admin) {
              final cluster = _fleetMarkers(tester).firstWhere(
                  (marker) => marker.key.toString().contains('cluster:'));
              await tester.tap(find.byKey(cluster.key!));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 120));
              expect(camera.camera.zoom, greaterThan(17));
              expect(camera.camera.zoom, lessThan(18));
              await tester.pump(const Duration(milliseconds: 400));
              camera.move(cluster.point, 18);
              await tester.pump();
              final depotCluster = _fleetMarkers(tester).firstWhere(
                  (marker) => marker.key.toString().contains('cluster:'));
              await tester.tap(find.byKey(depotCluster.key!));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              final search = find.byWidgetPredicate((widget) =>
                  widget is TextField &&
                  widget.decoration?.hintText == 'Search vehicle');
              expect(search, findsOneWidget);
              // Vehicle 4999 is in the other, currently offscreen depot.
              // The drawer searches the retained fleet, not just markers.
              await tester.enterText(search, 'Vehicle 4999');
              await tester.pump();
              expect(_vehicleLabel('Vehicle 4999'), findsOneWidget);
              await tester.tap(find.byTooltip('Close drawer'));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(search, findsNothing);
              await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 300));
              expect(search, findsOneWidget);
              await tester.enterText(search, 'Vehicle 4999');
              await tester.pump();
              expect(_vehicleLabel('Vehicle 4999'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            if (harness.controller.mounted) harness.controller.dispose();
            await tester.pump();
          }
        }, createHttpClient: (_) => _TileHttpClient());
      },
    );
  }

  testWidgets(
      '5000 fleet animates only bounded individual markers and keeps static layer stable',
      (tester) async {
    await HttpOverrides.runZoned(() async {
      final config = LiveMapRoleConfig.admin();
      dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false');
      SharedPreferences.setMockInitialValues({
        config.visualSettingsStorageKey: jsonEncode({
          'cluster': false,
          'vehicleLabel': true,
          'ripple': true,
        }),
      });
      final cache = LocalCache(await SharedPreferences.getInstance());
      final harness = _FleetHarness(config, sparse: true);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await tester.pumpWidget(_mapApp(cache, harness));
        await _flush(tester);
        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final camera = map.mapController!;
        camera.move(_pointFor(90, sparse: true), 17);
        await tester.pump();
        expect(_representedVehicles(tester), 200);
        expect(_fleetMarkers(tester), hasLength(200));
        final socket = harness.socket.telemetry.single..connect();
        harness.clock = harness.clock.add(const Duration(seconds: 1));
        socket.event('telemetry:update:batch', {
          'records': List.generate(5000, (index) {
            final point = _pointFor(index, burst: 1, sparse: true);
            return {
              'imei': 'imei-$index',
              'serverTime': harness.clock.toIso8601String(),
              'deviceTime': harness.clock.toIso8601String(),
              'latitude': point.latitude,
              'longitude': point.longitude,
              'speedKph': 35,
              'ignition': true,
            };
          }),
        });
        await tester.pump(const Duration(milliseconds: 500));
        final animated = tester.widget<MarkerLayer>(
            find.byKey(const ValueKey('fleet-animated-markers')));
        expect(animated.markers, isNotEmpty);
        expect(animated.markers.length,
            lessThanOrEqualTo(maxFleetAnimatedMarkers));
        _expectBoundedMarkers(tester);
        expect(_representedVehicles(tester), 200);
        final staticLayer = tester.widget<MarkerLayer>(
            find.byKey(const ValueKey('fleet-static-markers')));
        // Animation ticks should rebuild the moving layer without rebuilding
        // the static individuals or touching the 4800 offscreen vehicles.
        for (var frame = 0; frame < 8; frame++) {
          await tester.pump(const Duration(milliseconds: 34));
          expect(
              tester.widget<MarkerLayer>(
                  find.byKey(const ValueKey('fleet-static-markers'))),
              same(staticLayer));
          _expectBoundedMarkers(tester);
        }
        expect(harness.controller.state.telemetry.allCount, 5000);
        expect(tester.takeException(), isNull);
        camera.move(const LatLng(0, 0), 17);
        await tester.pump();
        expect(_fleetMarkers(tester), isEmpty);
        expect(
            find.byKey(const ValueKey('fleet-animated-markers')), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        if (harness.controller.mounted) harness.controller.dispose();
        await tester.pump();
      }
    }, createHttpClient: (_) => _TileHttpClient());
  });
}

Widget _mapApp(LocalCache cache, _FleetHarness harness) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _Auth(harness.config)),
        localCacheProvider.overrideWithValue(cache),
        liveMapVehicleServiceProvider.overrideWithValue(harness.service),
        liveMapEventsServiceProvider.overrideWithValue(harness.events),
        socketServiceProvider.overrideWithValue(harness.socket),
        liveMapControllerProvider.overrideWith((ref) {
          harness.controller.initialize();
          return harness.controller;
        }),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LiveMapScreen(config: harness.config),
      ),
    );

Finder _vehicleLabel(String name) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == name);

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

List<Marker> _fleetMarkers(WidgetTester tester) => [
      for (final key in const [
        'fleet-static-markers',
        'fleet-animated-markers'
      ])
        for (final layer
            in tester.widgetList<MarkerLayer>(find.byKey(ValueKey(key))))
          ...layer.markers,
    ];

void _expectBoundedMarkers(WidgetTester tester) {
  final markers = _fleetMarkers(tester);
  expect(markers.length, lessThanOrEqualTo(maxFleetMapMarkers));
  expect(
      markers.map((marker) => marker.key).toSet(), hasLength(markers.length));
  expect(markers.every((marker) => marker.key != null), isTrue);
}

int _representedVehicles(WidgetTester tester) {
  var count = 0;
  for (final marker in _fleetMarkers(tester)) {
    if (marker.key.toString().contains('cluster:')) {
      final label = tester
          .widgetList<Text>(find.descendant(
            of: find.byKey(marker.key!),
            matching: find.byType(Text),
          ))
          .map((text) => int.tryParse(text.data ?? ''))
          .whereType<int>()
          .single;
      count += label;
    } else {
      count++;
    }
  }
  return count;
}

LatLng _pointFor(int index, {int burst = 0, bool sparse = false}) {
  if (sparse && index < 200) {
    return LatLng(
      28.6139 + (index ~/ 20) * 0.00012 + burst * 0.00003,
      77.2090 + (index % 20) * 0.00012 + burst * 0.00003,
    );
  }
  final depotIndex = index % 2500;
  final row = depotIndex ~/ 50;
  final column = depotIndex % 50;
  final base = !sparse && index < 2500
      ? const LatLng(28.6139, 77.2090)
      : const LatLng(12.9716, 77.5946);
  return LatLng(
    base.latitude + row * 0.000002 + burst * 0.00003,
    base.longitude + column * 0.000002 + burst * 0.00003,
  );
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(LiveMapRoleConfig config)
      : super(AuthState.authenticated(CurrentUser(
          id: 'large-fleet-test',
          name: 'Fleet operator',
          email: '',
          role: switch (config.role) {
            LiveMapRole.superadmin => UserRole.superadmin,
            LiveMapRole.admin => UserRole.admin,
            _ => UserRole.user,
          },
        )));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FleetHarness {
  _FleetHarness(this.config, {bool sparse = false}) {
    service = _FleetService(config, clock, sparse: sparse);
    events = _EventsService(config);
    controller = LiveMapController(
      vehicleService: service,
      mapEventsService: events,
      socketService: socket,
      config: config,
      now: () => clock,
    );
  }
  final LiveMapRoleConfig config;
  DateTime clock = DateTime.now().toUtc();
  late final _FleetService service;
  late final _EventsService events;
  final socket = _SocketService();
  late final LiveMapController controller;
}

class _FleetService extends LiveMapVehicleService {
  _FleetService(LiveMapRoleConfig config, this.clock, {this.sparse = false})
      : super(apiClient: ApiClient(Dio()), config: config);
  final DateTime clock;
  final bool sparse;

  @override
  Future<LiveMapTelemetry> getMapTelemetry(
          {String? refreshKey,
          CancelToken? cancelToken,
          LiveMapVehicleTarget? target}) async =>
      parseMapTelemetryPayload(List.generate(5000, (index) {
        final point = _pointFor(index, sparse: sparse);
        return {
          'vehicleId': '$index',
          'vehicleName': 'Vehicle $index',
          'imei': 'imei-$index',
          'status': 'running',
          'telemetry': {
            'imei': 'imei-$index',
            'serverTime': clock.toIso8601String(),
            'deviceTime': clock.toIso8601String(),
            'latitude': point.latitude,
            'longitude': point.longitude,
            'speedKph': 35,
            'ignition': true,
          },
        };
      }));
}

class _EventsService extends LiveMapEventsService {
  _EventsService(LiveMapRoleConfig config)
      : super(apiClient: ApiClient(Dio()), config: config);

  @override
  Future<NotificationPage> getMapEvents({
    int limit = 50,
    String? beforeId,
    String? from,
    String? to,
    String? source,
    String? severity,
    CancelToken? cancelToken,
  }) async =>
      const NotificationPage(items: [], hasMore: false, unreadCount: 0);
}

class _SocketService extends SocketService {
  _SocketService()
      : super(TokenStorage(const FlutterSecureStorage()),
            apiBaseUrl: 'https://example.test/api');
  final telemetry = <_Connection>[];

  @override
  Future<SocketConnection> connect(String namespace,
      {bool authenticated = true}) async {
    final connection = _Connection();
    if (namespace == '/telemetry') telemetry.add(connection);
    return connection;
  }
}

class _Connection implements SocketConnection {
  final handlers = <String, List<SocketEventHandler>>{};
  final connects = <void Function()>[];
  final disconnects = <SocketEventHandler>[];
  @override
  bool isConnected = false;
  @override
  void emit(String name, [dynamic data]) {}
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
  void disconnect() => isConnected = false;
  void connect() {
    isConnected = true;
    for (final callback in connects) {
      callback();
    }
  }

  void event(String name, dynamic data) {
    for (final callback in handlers[name] ?? <SocketEventHandler>[]) {
      callback(data);
    }
  }
}

// Exercise real TileLayer and marker rendering without external network or
// error image noise. Tile image decode remains part of the real widget tree.
final _tileBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=');

class _TileHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _TileHttpRequest();
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _TileHttpRequest();
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TileHttpRequest implements HttpClientRequest {
  @override
  final headers = _TileHeaders();
  @override
  Future<void> addStream(Stream<List<int>> stream) async {}
  @override
  Future<HttpClientResponse> close() async => _TileHttpResponse();
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TileHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void forEach(void Function(String name, List<String> values) action) {}
  @override
  List<String>? operator [](String name) => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TileHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  final headers = _TileHeaders();
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => _tileBytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream.value(_tileBytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
