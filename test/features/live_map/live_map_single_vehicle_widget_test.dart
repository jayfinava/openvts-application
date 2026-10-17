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
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/router/route_paths.dart';
import 'package:open_vts/core/socket/socket_service.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/storage/token_storage.dart';
import 'package:open_vts/features/admin/controllers/admin_providers.dart';
import 'package:open_vts/features/admin/models/admin_vehicle_model.dart';
import 'package:open_vts/features/admin/screens/map/admin_map_screen.dart';
import 'package:open_vts/features/admin/screens/vehicles/admin_vehicles_screen.dart';
import 'package:open_vts/features/admin/services/admin_vehicle_service.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/live_map/controllers/live_map_controller.dart';
import 'package:open_vts/features/live_map/controllers/live_map_providers.dart';
import 'package:open_vts/features/live_map/models/live_map_role_config.dart';
import 'package:open_vts/features/live_map/models/live_map_vehicle_target.dart';
import 'package:open_vts/features/live_map/screens/live_map_screen.dart';
import 'package:open_vts/features/live_map/services/live_map_events_service.dart';
import 'package:open_vts/features/live_map/services/live_map_vehicle_service.dart';
import 'package:open_vts/features/notifications/models/app_notification.dart';
import 'package:open_vts/features/notifications/models/notification_page.dart';
import 'package:open_vts/features/superadmin/models/superadmin_map_overlay_model.dart';
import 'package:open_vts/features/superadmin/models/superadmin_vehicle_history_model.dart';
import 'package:open_vts/features/superadmin/models/superadmin_vehicle_model.dart';
import 'package:open_vts/features/superadmin/services/superadmin_vehicle_service.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/models/vehicle_summary.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fleet_wire_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final config in [
    LiveMapRoleConfig.superadmin(),
    LiveMapRoleConfig.admin(),
    LiveMapRoleConfig.user(),
  ]) {
    _testMap(
        '${config.role.name}: real HTTP service renders the selected map-v2 row',
        (tester, harness) async {
      harness.useRealVehicleService = true;
      await tester.pumpWidget(harness.app(LiveMapScreen(
          config: config,
          vehicleTarget:
              const LiveMapVehicleTarget(vehicleId: '2', imei: 'old-device'))));
      await _flush(tester);
      expect(_controller(tester).state.telemetry.vehicles.single.id, '2');
      expect(
          _controller(tester).state.telemetry.vehicles.single.imei, 'imei-2');
      expect(_markers(tester), hasLength(1));
      expect(_camera(tester).zoom, 16);
      expect(
          harness.requests.where(
              (request) => request.uri.path.endsWith('/map/v2/vehicles')),
          isEmpty);
      expect(tester.takeException(), isNull);
    }, config: config);

    _testMap(
        '${config.role.name}: cached snapshot hydrates a missing single marker',
        (tester, harness) async {
      harness.service.rows = [_row('2', harness.clock, location: false)];
      await tester.pumpWidget(harness.app(LiveMapScreen(
          config: config,
          vehicleTarget:
              const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'))));
      await _flush(tester);
      expect(_markers(tester), isEmpty);
      final socket = harness.socket.telemetry.single..connect();
      final snapshot = {
        ...harness.packet('2'),
        'satellites': 0,
        'valid': false
      };
      socket.event('telemetry:snapshot', [
        {...snapshot, 'imei': 'imei-1'},
        {...snapshot, 'vehicleId': '3'}
      ]);
      await _flush(tester);
      expect(_markers(tester), isEmpty);
      socket.event('telemetry:snapshot', [snapshot]);
      await _flush(tester);
      expect(_markers(tester), hasLength(1));
      expect(_markers(tester).single.point.latitude, 28.614);
      expect(_camera(tester).zoom, 16);
      expect(_camera(tester).center.latitude, closeTo(28.614, 0.00001));
      socket.event('telemetry:update', {
        ...snapshot,
        'latitude': 28.7,
        'serverTime':
            harness.clock.add(const Duration(seconds: 2)).toIso8601String()
      });
      await _flush(tester);
      expect(
          _controller(tester).state.telemetry.vehicles.single.latitude, 28.614,
          reason:
              'Ordinary packets with invalid GPS do not move the admitted fix.');
      socket.event('telemetry:update', {
        ...harness.packet('2', latitude: 28.6142),
        'serverTime':
            harness.clock.add(const Duration(seconds: 3)).toIso8601String()
      });
      await _flush(tester);
      expect(_controller(tester).state.telemetry.vehicles.single.latitude,
          28.6142);
      expect(tester.takeException(), isNull);
    }, config: config);

    _testMap('${config.role.name}: Commands fits a short drawer and keyboard',
        (tester, harness) async {
      tester.view.physicalSize = const Size(360, 800);
      harness.textScale = 2;
      await tester.pumpWidget(harness.app(LiveMapScreen(
          config: config,
          vehicleTarget:
              const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'))));
      await _flush(tester);
      await tester.tap(find.byKey(_markers(tester).single.key!));
      await _drawerAnimation(tester);
      final commandsTab = find.text('Commands');
      await tester.ensureVisible(commandsTab);
      await tester.tap(commandsTab);
      await _drawerAnimation(tester);
      await _flush(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(DropdownButtonFormField<String>).last);
      await _drawerAnimation(tester);
      await tester.tap(find.textContaining('Position Periodic Start').last);
      await _drawerAnimation(tester);
      final commandScroll = find.byType(CustomScrollView).last;
      final input = find.byType(TextField).last;
      await tester.ensureVisible(input);
      await tester.tap(input);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      await _drawerAnimation(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(commandScroll, const Offset(0, -450));
      await _drawerAnimation(tester);
      expect(find.text('History').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
    }, config: config);

    _testMap(
        '${config.role.name}: single vehicle scopes actual markers, live updates, drawer and history',
        (tester, harness) async {
      const target = LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2');
      await tester.pumpWidget(
          harness.app(LiveMapScreen(config: config, vehicleTarget: target)));
      await _flush(tester);
      final controller = _controller(tester);
      expect(controller.state.telemetry.vehicles.map((vehicle) => vehicle.id),
          ['2']);
      expect(controller.state.telemetry.allCount, 1);
      expect(_markers(tester), hasLength(1));
      expect(_markers(tester).single.key, const ValueKey('imei:imei-2'));
      expect(harness.service.eventImeis, ['imei-2']);
      final socket = harness.socket.telemetry.single..connect();
      final subscription = socket.emits
          .singleWhere((event) => event.$1 == 'telemetry:subscribe')
          .$2 as Map;
      expect(subscription['imeis'], ['imei-2']);
      expect(subscription['scope'], isNull);

      final originalVehicle = controller.state.telemetry.vehicles.single;
      socket.event('telemetry:update:batch', {
        'records': [harness.packet('1', speed: 99, latitude: 28.8)]
      });
      await _flush(tester);
      expect(controller.state.telemetry.vehicles.single, same(originalVehicle));
      final markerBefore = _markers(tester).single.point;
      socket.event('telemetry:update:batch', {
        'records': [harness.packet('2', speed: 55, latitude: 28.6143)]
      });
      await _flush(tester);
      final liveVehicle = controller.state.telemetry.vehicles.single;
      expect(liveVehicle.id, '2');
      expect(liveVehicle.speed, 55);
      expect(liveVehicle.latitude, 28.6143);
      expect(_markers(tester), hasLength(1));
      expect(_markers(tester).single.key, const ValueKey('imei:imei-2'));
      expect(_markers(tester).single.point.latitude,
          inInclusiveRange(markerBefore.latitude, liveVehicle.latitude));
      await tester.pump(const Duration(milliseconds: 34));
      expect(_markers(tester).single.point.latitude,
          greaterThan(markerBefore.latitude));

      final vehicleImages = tester.widgetList<Image>(find.byType(Image)).where(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName.contains('/vehicleicons/'));
      expect(vehicleImages, isNotEmpty);
      for (final image in vehicleImages) {
        expect(image.color, isNull,
            reason: 'Vehicle assets retain their original status colors.');
        expect(image.colorBlendMode, isNull);
      }
      expect(
          find.ancestor(
              of: find.byType(FlutterMap),
              matching: find.byType(ColorFiltered)),
          findsNothing);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
      await _drawerAnimation(tester);
      expect(_text('Vehicle 2'), findsAtLeastNWidgets(1));
      expect(_text('Vehicle 1'), findsNothing);
      expect(_text('Vehicle 3'), findsNothing);
      final search = find.byWidgetPredicate((widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Search vehicle');
      await tester.enterText(search, 'Vehicle 1');
      await tester.pump();
      expect(find.text('No vehicles found'), findsOneWidget);
      await tester.enterText(search, '');
      await tester.pump();
      await tester.tap(find.text('History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Get History'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final selector = tester.widget<DropdownButton<VehicleSummary>>(
          find.byType(DropdownButton<VehicleSummary>));
      expect(selector.items!.map((item) => item.value!.id), ['2']);
      expect(tester.takeException(), isNull);
    }, config: config);

    _testMap(
        '${config.role.name}: user camera survives refresh, reconnect and selected vehicle reappearance',
        (tester, harness) async {
      await tester.pumpWidget(harness.app(LiveMapScreen(
        config: config,
        vehicleTarget:
            const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
      )));
      await _flush(tester);
      final controller = _controller(tester);
      final socket = harness.socket.telemetry.single..connect();
      await _flush(tester);
      await _manuallyPositionMap(tester);
      final camera = _camera(tester);
      expect(camera.zoom, 17);

      await controller.refreshTelemetry();
      await _flush(tester);
      _expectCamera(tester, camera);
      harness.service.rows = [
        _row('2', harness.clock.add(const Duration(seconds: 2)),
            latitude: 28.6142)
      ];
      socket.drop();
      socket.connect();
      await _flush(tester);
      _expectCamera(tester, camera);
      expect(_controller(tester), same(controller));

      // A transient empty authorized response must not turn reappearance
      // into a new initial camera fit after the user has explored the map.
      harness.service.rows = [];
      await controller.refreshTelemetry();
      await _flush(tester);
      expect(controller.state.telemetry.vehicles, isEmpty);
      _expectCamera(tester, camera);
      harness.service.rows = [
        _row('2', harness.clock.add(const Duration(seconds: 3)),
            latitude: 28.6143)
      ];
      await controller.refreshTelemetry();
      await _flush(tester);
      expect(controller.state.telemetry.vehicles.single.id, '2');
      _expectCamera(tester, camera);
      expect(tester.takeException(), isNull);
    }, config: config);

    _testMap(
        '${config.role.name}: unavailable selected vehicle never falls back to the fleet',
        (tester, harness) async {
      await tester.pumpWidget(harness.app(LiveMapScreen(
        config: config,
        vehicleTarget:
            const LiveMapVehicleTarget(vehicleId: 'missing', imei: 'imei-1'),
      )));
      await _flush(tester);
      final controller = _controller(tester);
      expect(controller.state.telemetry.vehicles, isEmpty);
      expect(controller.state.telemetry.allCount, 0);
      expect(controller.state.errorMessage, contains('unavailable'));
      expect(_markers(tester), isEmpty);
      expect(harness.socket.telemetry, isEmpty);
      expect(harness.service.eventImeis, isEmpty);
      expect(tester.takeException(), isNull);
    }, config: config);
  }

  _testMap('first delayed socket snapshot focuses the selected vehicle once',
      (tester, harness) async {
    harness.service.rows = [_row('2', harness.clock, location: false)];
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    expect(_markers(tester), isEmpty);
    final socket = harness.socket.telemetry.single..connect();
    final subscription = socket.emits
        .singleWhere((event) => event.$1 == 'telemetry:subscribe')
        .$2 as Map;
    expect(subscription['snapshot'], isTrue);
    expect(subscription['delivery'], 'immediate');
    socket.event('telemetry:snapshot', [
      harness.packet('1', latitude: 18.0),
      harness.packet('2', latitude: 19.076),
    ]);
    await _flush(tester);
    expect(_markers(tester), hasLength(1));
    expect(_camera(tester).zoom, 16);
    expect(_camera(tester).center.latitude, 19.076);
    expect(_camera(tester).center.longitude, 77.209);
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'selected camera follows at the chosen zoom, pauses on pan and resumes explicitly',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    final map =
        tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
    final socket = harness.socket.telemetry.single..connect();
    map.move(_camera(tester).center, 16.2);
    await tester.pump();
    socket.event('telemetry:update', {
      ...harness.packet('2', latitude: 28.6151),
      'serverTime':
          harness.clock.add(const Duration(seconds: 10)).toIso8601String(),
      'deviceTime':
          harness.clock.add(const Duration(seconds: 10)).toIso8601String(),
    });
    await _flush(tester);
    expect(_camera(tester).zoom, closeTo(16.2, 0.000001));
    expect(_camera(tester).center.latitude,
        closeTo(_markers(tester).single.point.latitude, 0.00001));
    expect(_camera(tester).center.latitude, greaterThan(28.6141));

    await tester.drag(find.byType(FlutterMap), const Offset(90, 60));
    await tester.pump(const Duration(milliseconds: 300));
    final pausedCamera = _camera(tester);
    socket.event('telemetry:update', {
      ...harness.packet('2', latitude: 28.6161),
      'serverTime':
          harness.clock.add(const Duration(seconds: 20)).toIso8601String(),
      'deviceTime':
          harness.clock.add(const Duration(seconds: 20)).toIso8601String(),
    });
    await _flush(tester);
    _expectCamera(tester, pausedCamera);
    await tester
        .tap(find.byKey(const ValueKey('single-vehicle-follow-control')));
    await _drawerAnimation(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_camera(tester).zoom, closeTo(pausedCamera.zoom, 0.000001));
    expect(_camera(tester).center.latitude,
        closeTo(_markers(tester).single.point.latitude, 0.00001));
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'manual camera before the first fix survives delayed location arrival',
      (tester, harness) async {
    harness.service.rows = [_row('2', harness.clock, location: false)];
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    await _manuallyPositionMap(tester);
    final camera = _camera(tester);
    final socket = harness.socket.telemetry.single..connect();
    socket.event('telemetry:update', harness.packet('2', latitude: 19.076));
    await _flush(tester);
    expect(_controller(tester).state.telemetry.vehicles.single.hasValidLocation,
        isTrue);
    _expectCamera(tester, camera);
    expect(tester.takeException(), isNull);
  });

  for (final modal in ['vehicle', 'settings', 'history']) {
    _testMap(
        '$modal modal reuses the map controller and its fresh selected telemetry',
        (tester, harness) async {
      await tester.pumpWidget(harness.app(LiveMapScreen(
        config: harness.config,
        vehicleTarget:
            const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
      )));
      await _flush(tester);
      final controller = _controller(tester);
      final socket = harness.socket.telemetry.single..connect();
      socket.event('telemetry:update',
          harness.packet('2', speed: 55, latitude: 28.6142));
      await _flush(tester);
      expect(controller.state.telemetry.vehicles.single.speed, 55);
      final loads = harness.service.telemetryLoads;
      late Finder modalContent;
      if (modal == 'vehicle') {
        await tester.tap(find.byKey(_markers(tester).single.key!));
        await _drawerAnimation(tester);
        modalContent = find.text('Details');
      } else if (modal == 'settings') {
        await tester.tap(find.byIcon(Icons.settings_rounded));
        await _drawerAnimation(tester);
        modalContent = find.text('Vehicle Label');
      } else {
        await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
        await _drawerAnimation(tester);
        await tester.tap(find.text('History'));
        await _drawerAnimation(tester);
        await tester.tap(find.text('Get History'));
        await _drawerAnimation(tester);
        modalContent = find.byType(DropdownButton<VehicleSummary>);
      }
      final modalContainer =
          ProviderScope.containerOf(tester.element(modalContent));
      expect(modalContainer.read(liveMapControllerProvider.notifier),
          same(controller));
      await _flush(tester);
      expect(harness.service.telemetryLoads, loads);
      expect(harness.socket.telemetry, hasLength(1));
      expect(
          modalContainer
              .read(liveMapControllerProvider)
              .telemetry
              .vehicles
              .single
              .speed,
          55);
      socket.event('telemetry:update', {
        ...harness.packet('2', speed: 67, latitude: 28.6152),
        'serverTime':
            harness.clock.add(const Duration(seconds: 2)).toIso8601String(),
      });
      await _flush(tester);
      expect(
          modalContainer
              .read(liveMapControllerProvider)
              .telemetry
              .vehicles
              .single
              .speed,
          67);
      expect(controller.state.telemetry.vehicles.single.latitude, 28.6152);
      expect(harness.service.telemetryLoads, loads);
      expect(tester.takeException(), isNull);
    });
  }

  _testMap('metadata heartbeats do not make the Last GPS HUD appear fresh',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    final originalLabel = _lastGpsLabel(tester);
    final originalFix =
        _controller(tester).state.telemetry.vehicles.single.locationServerTime;
    final socket = harness.socket.telemetry.single..connect();
    socket.event('telemetry:update', {
      'imei': 'imei-2',
      'serverTime':
          harness.clock.add(const Duration(seconds: 60)).toIso8601String(),
      'ignition': false,
    });
    await _flush(tester);
    expect(_lastGpsLabel(tester), originalLabel);
    expect(
        _controller(tester).state.telemetry.vehicles.single.locationServerTime,
        originalFix);
    socket.event('telemetry:update', {
      ...harness.packet('2', latitude: 28.6161),
      'serverTime':
          harness.clock.add(const Duration(seconds: 5)).toIso8601String(),
      'deviceTime':
          harness.clock.add(const Duration(seconds: 5)).toIso8601String(),
    });
    await _flush(tester);
    expect(_lastGpsLabel(tester), isNot(originalLabel));
    expect(
        _controller(tester).state.telemetry.vehicles.single.latitude, 28.6161);
    expect(
        _controller(tester).state.telemetry.vehicles.single.locationServerTime,
        harness.clock.add(const Duration(seconds: 5)));
    expect(tester.takeException(), isNull);
  });

  _testMap('clearing history restores the manually chosen live camera',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    await _manuallyPositionMap(tester);
    tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .rotate(25);
    await tester.pump();
    final liveCamera = _camera(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(FlutterMap)));
    final history =
        container.read(liveMapVehicleHistoryControllerProvider.notifier);
    await history.loadHistory(_historyRequest(tester, harness));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(history.state.history!.validPathPoints, hasLength(3));
    expect(_camera(tester).center.latitude, greaterThan(37));
    history.clearHistory();
    await _flush(tester);
    _expectCamera(tester, liveCamera);
    final socket = harness.socket.telemetry.single..connect();
    socket.event('telemetry:update', harness.packet('2', latitude: 28.7));
    await _flush(tester);
    _expectCamera(tester, liveCamera);
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'failed history does not undo a user gesture while the request loads',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    harness.service.pendingHistory = Completer<LiveMapVehicleHistory>();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(FlutterMap)));
    final history =
        container.read(liveMapVehicleHistoryControllerProvider.notifier);
    final load = history.loadHistory(_historyRequest(tester, harness));
    await tester.pump();
    expect(history.state.isLoading, isTrue);
    await _manuallyPositionMap(tester);
    final userCamera = _camera(tester);
    harness.service.pendingHistory!
        .completeError(Exception('History unavailable'));
    await load;
    await _flush(tester);
    expect(history.state.errorMessage, 'History unavailable');
    _expectCamera(tester, userCamera);
    final socket = harness.socket.telemetry.single..connect();
    socket.event('telemetry:update', harness.packet('2', latitude: 28.7));
    await _flush(tester);
    _expectCamera(tester, userCamera);
    expect(tester.takeException(), isNull);
  });

  _testMap('first live GPS fix leaves active history camera intact',
      (tester, harness) async {
    harness.service.rows = [_row('2', harness.clock, location: false)];
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(FlutterMap)));
    final history =
        container.read(liveMapVehicleHistoryControllerProvider.notifier);
    await history.loadHistory(_historyRequest(tester, harness));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final historyCamera = _camera(tester);
    expect(historyCamera.center.latitude, greaterThan(37));
    final socket = harness.socket.telemetry.single..connect();
    socket.event('telemetry:snapshot', [harness.packet('2', latitude: 19.076)]);
    await _flush(tester);
    expect(
        _controller(tester).state.telemetry.vehicles.single.latitude, 19.076);
    _expectCamera(tester, historyCamera);
    history.clearHistory();
    await _flush(tester);
    expect(_camera(tester).center.latitude, closeTo(19.076, 0.000001));
    expect(_camera(tester).zoom, 16);
    expect(tester.takeException(), isNull);
  });

  _testMap('clearing replay restores live zoom, rotation and paused follow',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    await _manuallyPositionMap(tester);
    tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .rotate(20);
    await tester.pump();
    // The marker must be visible to open the actual vehicle drawer.
    tester
        .widget<FlutterMap>(find.byType(FlutterMap))
        .mapController!
        .move(_markers(tester).single.point, _camera(tester).zoom);
    await tester.pump();
    await tester.tap(find.byKey(_markers(tester).single.key!));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 400));
    final liveCamera = _camera(tester);
    await tester.tap(find.text('replay'));
    await _drawerAnimation(tester);
    await tester.ensureVisible(find.text('Get Replay'));
    await _flush(tester);
    await tester.tap(find.text('Get Replay'));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byTooltip('Clear replay'), findsOneWidget);
    expect(_camera(tester).center.latitude, greaterThan(37));
    await tester.tap(find.byTooltip('Clear replay'));
    await _flush(tester);
    _expectCamera(tester, liveCamera);
    final socket = harness.socket.telemetry.single..connect();
    socket.event('telemetry:update', harness.packet('2', latitude: 28.7));
    await _flush(tester);
    _expectCamera(tester, liveCamera);
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'a snapped location during vehicle focus catches up without another packet',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(
      config: harness.config,
      vehicleTarget: const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'),
    )));
    await _flush(tester);
    final socket = harness.socket.telemetry.single..connect();
    await tester.tap(find.byKey(_markers(tester).single.key!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    socket.event('telemetry:update', harness.packet('2', latitude: 19.076));
    await _flush(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(_camera(tester).zoom, 16);
    expect(_camera(tester).center.latitude, inInclusiveRange(19.07, 19.08));
    expect(_markers(tester).single.point.latitude, 19.076);
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'changing target while vehicle details are open safely replaces the map scope',
      (tester, harness) async {
    final target = ValueNotifier<LiveMapVehicleTarget?>(
        const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'));
    addTearDown(target.dispose);
    await tester.pumpWidget(harness.app(ValueListenableBuilder(
      valueListenable: target,
      builder: (context, value, child) =>
          LiveMapScreen(config: harness.config, vehicleTarget: value),
    )));
    await _flush(tester);
    final previous = _controller(tester);
    final previousSocket = harness.socket.telemetry.single..connect();
    await tester.tap(find.byKey(_markers(tester).single.key!));
    await _drawerAnimation(tester);
    expect(find.text('Details'), findsOneWidget);
    // Queue a Consumer rebuild in the borrowed modal container at the same
    // time the selected-map ProviderScope is replaced.
    previousSocket.event(
        'telemetry:update', harness.packet('2', speed: 67, latitude: 28.6142));
    target.value = const LiveMapVehicleTarget(vehicleId: '3', imei: 'imei-3');
    await _flush(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(previous.mounted, isFalse);
    expect(previousSocket.disconnected, isTrue);
    expect(find.text('Details'), findsNothing);
    expect(_controller(tester).state.telemetry.vehicles.single.id, '3');
    expect(_markers(tester).single.key, const ValueKey('imei:imei-3'));
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'changing selected target recreates its scope and ordinary map uses the fleet scene',
      (tester, harness) async {
    final target = ValueNotifier<LiveMapVehicleTarget?>(
        const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'));
    addTearDown(target.dispose);
    await tester.pumpWidget(harness.app(ValueListenableBuilder(
      valueListenable: target,
      builder: (context, value, child) =>
          LiveMapScreen(config: harness.config, vehicleTarget: value),
    )));
    await _flush(tester);
    final oldController = _controller(tester);
    final oldSocket = harness.socket.telemetry.single..connect();
    expect(oldController.state.telemetry.vehicles.single.id, '2');

    target.value = const LiveMapVehicleTarget(vehicleId: '3', imei: 'imei-3');
    await _flush(tester);
    final nextController = _controller(tester);
    expect(nextController, isNot(same(oldController)));
    expect(oldController.mounted, isFalse);
    expect(oldSocket.disconnected, isTrue);
    expect(nextController.state.telemetry.vehicles.single.id, '3');
    expect(_markers(tester).single.key, const ValueKey('imei:imei-3'));
    oldSocket.event('telemetry:update', harness.packet('2', speed: 99));
    await _flush(tester);
    expect(nextController.state.telemetry.vehicles.single.id, '3');

    target.value = null;
    await _flush(tester);
    final fleetSocket = harness.socket.maps.single..connect();
    fleetSocket.event('map:open', fleetEnvelope(scene: 0, interest: 0));
    _sendFleetScene(fleetSocket, harness.clock, count: 3);
    await _flush(tester);
    final fleetController = _controller(tester);
    expect(fleetController.state.telemetry.vehicles, hasLength(3));
    expect(fleetController.state.telemetry.allCount, 3);
    expect(_markers(tester), hasLength(3));
    expect(_markers(tester).map((marker) => marker.key).toSet(), {
      const ValueKey('imei:imei-1'),
      const ValueKey('imei:imei-2'),
      const ValueKey('imei:imei-3'),
    });
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'pending or failed geofences never cover or hide the selected vehicle',
      (tester, harness) async {
    harness.delayedGeofences = Completer<List<SuperadminMapGeofence>>();
    await tester.pumpWidget(harness.app(LiveMapScreen(
        config: harness.config,
        vehicleTarget:
            const LiveMapVehicleTarget(vehicleId: '2', imei: 'imei-2'))));
    await _flush(tester);
    expect(_markers(tester), hasLength(1));
    expect(find.text('Loading geofences'), findsNothing);
    harness.delayedGeofences!.completeError(StateError('Overlay unavailable'));
    await _flush(tester);
    expect(_markers(tester), hasLength(1));
    expect(find.text('geofences unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  }, config: LiveMapRoleConfig.superadmin(), showGeofence: true);

  _testMap(
      'production fleet map handles 5000 scene leaves, lazy paging and global search',
      (tester, harness) async {
    await tester.pumpWidget(harness.app(LiveMapScreen(config: harness.config)));
    await _flush(tester);
    final socket = harness.socket.maps.single..connect();
    socket.event('map:open', fleetEnvelope(scene: 0, interest: 0));
    _sendFleetScene(socket, harness.clock, count: 5000, clusterOnly: true);
    await _flush(tester);
    expect(_controller(tester).state.telemetry.allCount, 5000);
    final cluster = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_VehicleClusterMarker');
    expect(cluster, findsOneWidget);
    final zoomBefore = _camera(tester).zoom;
    await tester.tap(cluster);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(_camera(tester).zoom, greaterThan(zoomBefore));
    await tester.pump(const Duration(milliseconds: 400));
    final focused = _camera(tester);
    _sendFleetScene(socket, harness.clock, count: 5000, revision: 2);
    await _flush(tester);
    _expectCamera(tester, focused);
    expect(_markers(tester).length, lessThanOrEqualTo(250));
    expect(harness.requests, isEmpty);
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await _drawerAnimation(tester);
    await _flush(tester);
    expect(
        find.byKey(const ValueKey('fleet-directory-search')), findsOneWidget);
    expect(_controller(tester).state.fleet!.directory, hasLength(100));
    expect(harness.requests.any((r) => r.uri.path.contains('map-telemetry')),
        isFalse);
    await tester.enterText(
        find.byKey(const ValueKey('fleet-directory-search')), 'vehicle-19999');
    await tester.pump(const Duration(milliseconds: 350));
    await _flush(tester);
    expect(
        harness.requests
            .where((r) => r.uri.path.endsWith('/vehicles'))
            .last
            .queryParameters['search'],
        'vehicle-19999');
    expect(_controller(tester).state.fleet!.directory.single.id, '19999');
    await tester.tap(find.byKey(const ValueKey('19999')));
    await _flush(tester);
    await _drawerAnimation(tester);
    expect(find.text('Details'), findsOneWidget);
    expect(
        _controller(tester)
            .state
            .telemetry
            .vehicles
            .any((v) => v.id == '19999'),
        isTrue);
    expect(
        harness.requests.where((r) => r.uri.path.endsWith('/vehicles/19999')),
        hasLength(1));
    expect(harness.socket.maps, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  _testMap(
      'actual admin vehicle card opens a single map and closing preserves list search',
      (tester, harness) async {
    final listService = _AdminVehicleService();
    final router = GoRouter(
      initialLocation: RoutePaths.adminVehicles,
      routes: [
        GoRoute(
          path: RoutePaths.adminVehicles,
          builder: (context, state) => const AdminVehiclesScreen(),
        ),
        GoRoute(
          path: RoutePaths.adminVehicleTracking,
          builder: (context, state) => AdminMapScreen(
            vehicleTarget: LiveMapVehicleTarget(
              vehicleId: state.pathParameters['vehicleId']!,
              imei: state.uri.queryParameters['imei'] ?? '',
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...harness.overrides,
        adminVehicleServiceProvider.overrideWithValue(listService),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await _flush(tester);
    final listSearch = find.byWidgetPredicate((widget) =>
        widget is TextField &&
        (widget.decoration?.hintText?.startsWith('Search vehicle,') ?? false));
    await tester.enterText(listSearch, 'Vehicle 2');
    await _flush(tester);
    final listContainer = ProviderScope.containerOf(
        tester.element(find.byType(AdminVehiclesScreen)));
    final listController =
        listContainer.read(adminVehiclesControllerProvider.notifier);
    expect(listController.state.searchQuery, 'Vehicle 2');
    expect(find.byTooltip('Track vehicle'), findsOneWidget);
    await tester.tap(find.byTooltip('Track vehicle'));
    await _flush(tester);
    expect(find.byType(AdminMapScreen), findsOneWidget);
    expect(_controller(tester).state.telemetry.vehicles.single.id, '2');
    expect(_markers(tester), hasLength(1));
    await tester.tap(find.byTooltip('Close map'));
    await _flush(tester);
    expect(router.routeInformationProvider.value.uri.path,
        RoutePaths.adminVehicles);
    expect(find.byType(AdminVehiclesScreen), findsOneWidget);
    expect(find.byType(AdminMapScreen), findsNothing);
    expect(listContainer.read(adminVehiclesControllerProvider.notifier),
        same(listController));
    expect(listController.state.searchQuery, 'Vehicle 2');
    expect(tester.widget<TextField>(listSearch).controller!.text, 'Vehicle 2');
    expect(listService.loads, 0);
    expect(
        harness.requests.where((r) => r.uri.path.endsWith('/admin/vehicles')),
        hasLength(2));
    expect(tester.takeException(), isNull);
  });
}

void _testMap(
    String description, Future<void> Function(WidgetTester, _Harness) body,
    {LiveMapRoleConfig? config, bool showGeofence = false}) {
  testWidgets(description, (tester) async {
    await HttpOverrides.runZoned(() async {
      dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false');
      final roleConfig = config ?? LiveMapRoleConfig.admin();
      SharedPreferences.setMockInitialValues({
        roleConfig.visualSettingsStorageKey: jsonEncode({
          'cluster': false,
          'vehicleLabel': true,
          'ripple': false,
          'geofence': showGeofence,
          'poi': false,
          'route': false,
        }),
      });
      final cache = LocalCache(await SharedPreferences.getInstance());
      final harness = _Harness(roleConfig, cache);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      try {
        await body(tester, harness);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        harness.dio.close(force: true);
      }
    }, createHttpClient: (_) => _TileHttpClient());
  });
}

Future<void> _flush(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> _drawerAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

MapCamera _camera(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

Future<void> _manuallyPositionMap(WidgetTester tester) async {
  tester
      .widget<FlutterMap>(find.byType(FlutterMap))
      .mapController!
      .move(const LatLng(28.6141, 77.209), 17);
  await tester.pump();
  await tester.drag(find.byType(FlutterMap), const Offset(90, 60));
  await tester.pump(const Duration(milliseconds: 300));
}

void _expectCamera(WidgetTester tester, MapCamera camera) {
  final current = _camera(tester);
  expect(current.zoom, closeTo(camera.zoom, 0.000001));
  expect(current.center.latitude, closeTo(camera.center.latitude, 0.000001));
  expect(current.center.longitude, closeTo(camera.center.longitude, 0.000001));
  expect(current.rotation, closeTo(camera.rotation, 0.000001));
}

Map<String, dynamic> _row(String id, DateTime clock,
        {bool location = true, double latitude = 28.6141}) =>
    {
      'vehicleId': id,
      'vehicleName': 'Vehicle $id',
      'imei': 'imei-$id',
      'status': 'running',
      'telemetry': location
          ? {
              'imei': 'imei-$id',
              'serverTime': clock.toIso8601String(),
              'deviceTime': clock.toIso8601String(),
              'latitude': latitude,
              'longitude': 77.209,
              'speedKph': 35,
              'ignition': true,
            }
          : null,
    };

LiveMapController _controller(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(FlutterMap)))
        .read(liveMapControllerProvider.notifier);

List<Marker> _markers(WidgetTester tester) => [
      for (final key in const [
        'fleet-static-markers',
        'fleet-animated-markers'
      ])
        for (final layer
            in tester.widgetList<MarkerLayer>(find.byKey(ValueKey(key))))
          ...layer.markers,
    ];

Finder _text(String name) =>
    find.byWidgetPredicate((widget) => widget is Text && widget.data == name);

SuperadminVehicleHistoryRequest _historyRequest(
        WidgetTester tester, _Harness harness) =>
    SuperadminVehicleHistoryRequest(
      vehicle: _controller(tester).state.telemetry.vehicles.single,
      from: harness.clock.subtract(const Duration(hours: 1)),
      to: harness.clock,
      stopMinutes: 5,
    );

List<Map<String, dynamic>> _pathPoints(DateTime clock) => [
      for (var index = 0; index < 3; index++)
        {
          'latitude': 37.77 + index * 0.005,
          'longitude': -122.4 + index * 0.005,
          'serverTime': clock
              .subtract(Duration(minutes: 20 - index * 5))
              .toIso8601String(),
          'deviceTime': clock
              .subtract(Duration(minutes: 20 - index * 5))
              .toIso8601String(),
          'speedKph': 20,
          'ignition': true,
        },
    ];

String _lastGpsLabel(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
      of: find.byKey(const ValueKey('single-vehicle-tracking-status')),
      matching: find.byType(Text),
    ))
    .map((text) => text.data ?? '')
    .singleWhere((value) => value.startsWith('Last GPS:'));

class _Harness {
  _Harness(this.config, this.cache) {
    service = _Vehicles(config, clock);
    events = _Events(config);
    dio = Dio(BaseOptions(baseUrl: 'https://example.test/api'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) {
      requests.add(request);
      final search = request.queryParameters['search'] ?? '';
      final cursor = request.queryParameters['cursor'];
      final start = cursor == null ? 0 : 100;
      dynamic data = {'rows': <dynamic>[]};
      if (request.uri.path.endsWith('/admin/vehicles')) {
        final rows = List.generate(
                3,
                (i) => {
                      'id': i + 1,
                      'name': 'Vehicle ${i + 1}',
                      'imei': 'imei-${i + 1}',
                      'isActive': true
                    })
            .where((row) => '${row['name']}'
                .toLowerCase()
                .contains('$search'.toLowerCase()))
            .toList();
        data = {
          'vehicles': rows,
          'pagination': {
            'page': request.queryParameters['page'],
            'limit': request.queryParameters['limit'],
            'total': rows.length
          }
        };
      } else if (request.uri.path.endsWith('/map/v2/vehicles/2')) {
        final row = fleetDirectoryRow(2, now: clock);
        (row['state'] as Map)['satellites'] = 0;
        data = {'row': row};
      } else if (request.uri.path.endsWith('/vehicles')) {
        data = {
          'rows': search == 'vehicle-19999'
              ? [fleetDirectoryRow(19999, now: clock)]
              : List.generate(
                  100, (i) => fleetDirectoryRow(start + i + 1, now: clock)),
          'hasMore': search == '',
          'total': search == '' ? 5000 : 1,
          'pageStart': start,
          'nextCursor': search == '' ? 'next-${start + 100}' : null,
          'previousCursor': start == 0 ? null : 'previous',
          'queryRevision': 'query-$search',
          'scopeRevision': 'scope'
        };
      } else if (RegExp(r'/map/v2/vehicles/\d+$').hasMatch(request.uri.path)) {
        data = {
          'row': fleetDirectoryRow(int.parse(request.uri.path.split('/').last),
              now: clock)
        };
      }
      handler.resolve(Response(
          requestOptions: request,
          statusCode: 200,
          data: {'action': true, 'data': data}));
    }));
  }
  late final Dio dio;
  Completer<List<SuperadminMapGeofence>>? delayedGeofences;
  final requests = <RequestOptions>[];
  final LiveMapRoleConfig config;
  final LocalCache cache;
  final clock = DateTime.now().toUtc();
  late final _Vehicles service;
  late final _Events events;
  final socket = _Sockets();
  bool useRealVehicleService = false;
  double textScale = 1;
  List<Override> get overrides => [
        if (delayedGeofences != null)
          liveMapGeofencesProvider
              .overrideWith((ref) => delayedGeofences!.future),
        authControllerProvider.overrideWith((ref) => _Auth(config)),
        localCacheProvider.overrideWithValue(cache),
        if (!useRealVehicleService)
          liveMapVehicleServiceProvider.overrideWithValue(service),
        liveMapEventsServiceProvider.overrideWithValue(events),
        socketServiceProvider.overrideWithValue(socket),
        apiClientProvider.overrideWithValue(ApiClient(dio)),
      ];
  Widget app(Widget child) => ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: child,
        ),
      );

  Map<String, dynamic> packet(String id,
          {double speed = 35, double latitude = 28.614}) =>
      {
        'imei': 'imei-$id',
        'serverTime': clock.add(const Duration(seconds: 1)).toIso8601String(),
        'deviceTime': clock.add(const Duration(seconds: 1)).toIso8601String(),
        'latitude': latitude,
        'longitude': 77.209,
        'speedKph': speed,
        'ignition': true,
      };
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(LiveMapRoleConfig config)
      : super(AuthState.authenticated(CurrentUser(
          id: 'operator',
          name: 'Operator',
          email: '',
          role: switch (config.role) {
            LiveMapRole.superadmin => UserRole.superadmin,
            LiveMapRole.admin => UserRole.admin,
            _ => UserRole.user,
          },
          access: const MobileAccess(
              loaded: true, features: {'maps': true, 'vehicles': true}),
        )));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Vehicles extends LiveMapVehicleService {
  _Vehicles(LiveMapRoleConfig config, this.clock)
      : super(apiClient: ApiClient(Dio()), config: config);
  final DateTime clock;
  final eventImeis = <String>[];
  List<dynamic>? rows;
  int telemetryLoads = 0;
  Completer<LiveMapVehicleHistory>? pendingHistory;

  @override
  Future<List<LiveMapCustomCommand>> getCustomCommands(
          {int? deviceTypeId, bool activeOnly = true}) async =>
      const [
        SuperadminCustomCommand(
            id: '1',
            command: 'TIMER,{Timer}#',
            isActive: true,
            commandTypeName:
                'Position Periodic Start with a very long template name',
            deviceTypeName: 'GT06',
            protocol: 'gt06'),
      ];
  @override
  Future<List<LiveMapSystemVariable>> getSystemVariables() async => [];
  @override
  Future<LiveMapCommandHistoryPage> getCommandHistoryByImei(
          {required String imei, int limit = 50, String? cursorId}) async =>
      const SuperadminCommandHistoryPage(items: []);
  @override
  Future<LiveMapCommandHistoryPage> getCommandHistoryByVehicleId(
          {required String vehicleId,
          int limit = 50,
          String? cursorId}) async =>
      const SuperadminCommandHistoryPage(items: []);

  @override
  Future<LiveMapVehicleHistory> getVehicleHistory(
      SuperadminVehicleHistoryRequest request,
      {int maxPoints = 5000,
      CancelToken? cancelToken,
      LiveMapVehicleTarget? target}) async {
    if (pendingHistory != null) return pendingHistory!.future;
    return SuperadminVehicleService(ApiClient(Dio()))
        .parseVehicleHistoryPayload({'points': _pathPoints(clock)}, request);
  }

  @override
  Future<SuperadminVehicleReplay> getVehicleReplayByImei({
    required String imei,
    required DateTime from,
    required DateTime to,
    int maxPoints = 5000,
    CancelToken? cancelToken,
  }) async =>
      SuperadminVehicleReplay.fromJson({
        'imei': imei,
        'from': from.toIso8601String(),
        'to': to.toIso8601String(),
        'points': _pathPoints(clock),
      });
  @override
  Future<LiveMapTelemetry> getMapTelemetry(
      {String? refreshKey,
      CancelToken? cancelToken,
      LiveMapVehicleTarget? target}) async {
    telemetryLoads++;
    return parseMapTelemetryPayload(rows ??
        List.generate(3, (index) {
          final id = '${index + 1}';
          return {
            'vehicleId': id,
            'vehicleName': 'Vehicle $id',
            'imei': 'imei-$id',
            'status': 'running',
            'telemetry': {
              'imei': 'imei-$id',
              'serverTime': clock.toIso8601String(),
              'deviceTime': clock.toIso8601String(),
              'latitude': 28.614 + index * 0.0001,
              'longitude': 77.209,
              'speedKph': 35,
              'ignition': true,
            },
          };
        }));
  }

  @override
  Future<LiveMapVehicleDetails> getVehicleDetailsByImei(String imei) async =>
      const SuperadminVehicleDetails.empty();

  @override
  Future<LiveMapVehicleEventPage> getVehicleEventsByImei(String imei,
      {int limit = 50, String? beforeId}) async {
    eventImeis.add(imei);
    return const SuperadminVehicleEventPage(items: []);
  }
}

class _Events extends LiveMapEventsService {
  _Events(LiveMapRoleConfig config)
      : super(apiClient: ApiClient(Dio()), config: config);
  @override
  Future<NotificationPage> getMapEvents(
          {int limit = 50,
          String? beforeId,
          String? from,
          String? to,
          String? source,
          String? severity,
          CancelToken? cancelToken,
          LiveMapVehicleTarget? target}) async =>
      const NotificationPage(
          items: <AppNotification>[], hasMore: false, unreadCount: 0);
}

class _AdminVehicleService extends AdminVehicleService {
  _AdminVehicleService() : super(ApiClient(Dio()));
  int loads = 0;
  @override
  Future<List<AdminVehicleListItem>> getVehicles({String? refreshKey}) async {
    loads++;
    return List.generate(
        3,
        (index) => AdminVehicleListItem.fromJson({
              'id': '${index + 1}',
              'name': 'Vehicle ${index + 1}',
              'imei': 'imei-${index + 1}',
              'isActive': true,
            }));
  }
}

void _sendFleetScene(_Connection connection, DateTime clock,
    {required int count, bool clusterOnly = false, int revision = 1}) {
  final interest = connection.emits
      .lastWhere((e) => e.$1 == 'map:set-interest')
      .$2['interestRevision'] as int;
  final envelope = fleetEnvelope(interest: interest, scene: revision);
  connection.event('map:summary',
      fleetSummary(total: count, interest: interest, scene: revision));
  final items = clusterOnly
      ? <Map<String, dynamic>>[
          {
            'id': 'c:1',
            'kind': 'cluster',
            'clusterId': 1,
            'count': count,
            'latitude': 28.617,
            'longitude': 77.209,
            'bounds': [77.208, 28.614, 77.210, 28.619],
          }
        ]
      : List.generate(count, (i) => fleetWireVehicle(i + 1, now: clock));
  final chunks = (items.length / 256).ceil();
  connection.event('map:scene-start',
      {...envelope, 'expectedChunks': chunks, 'expectedCount': items.length});
  for (var i = 0; i < chunks; i++) {
    connection.event('map:scene-chunk', {
      ...envelope,
      'chunkIndex': i,
      'items': items.skip(i * 256).take(256).toList(),
    });
  }
  connection
      .event('map:scene-end', {...envelope, 'expectedCount': items.length});
}

class _Sockets extends SocketService {
  _Sockets()
      : super(TokenStorage(const FlutterSecureStorage()),
            apiBaseUrl: 'https://example.test/api');
  final telemetry = <_Connection>[];
  final maps = <_Connection>[];
  @override
  Future<SocketConnection> connect(String namespace,
      {bool authenticated = true}) async {
    final connection = _Connection();
    if (namespace == '/telemetry') telemetry.add(connection);
    if (namespace == '/map-v2') maps.add(connection);
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
    isConnected = false;
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
