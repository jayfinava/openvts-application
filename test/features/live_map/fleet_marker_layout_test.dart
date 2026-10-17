import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_vts/features/live_map/rendering/fleet_marker_layout.dart';
import 'package:open_vts/shared/models/vehicle_summary.dart';

void main() {
  group('Fleet marker rendering budget', () {
    test('server cluster weights and selected leaves survive the mobile budget',
        () {
      final camera = _camera(width: 1600, height: 1000);
      final leaves = _distributedFleet(camera, 100);
      final centers = _distributedFleet(camera, 1000);
      final layout = buildServerFleetMarkerLayout(
        vehicles: leaves,
        camera: camera,
        selectedVehicleKey: fleetVehicleKey(leaves.first),
        clusters: [
          for (var i = 0; i < centers.length; i++)
            {
              'id': 'c:$i',
              'count': 10,
              'latitude': centers[i].latitude,
              'longitude': centers[i].longitude,
              'bounds': [
                centers[i].longitude,
                centers[i].latitude,
                centers[i].longitude,
                centers[i].latitude
              ],
            }
        ],
      );
      _expectConservedLayout(layout, 10100);
      expect(
          layout.groups
              .singleWhere((g) => g.key == fleetVehicleKey(leaves.first))
              .vehicle,
          same(leaves.first));
    });

    for (final fleetSize in [5000, 10000]) {
      test('$fleetSize distributed vehicles retain every count', () {
        final camera = _camera(width: 1600, height: 1000);
        final fleet = _distributedFleet(camera, fleetSize);
        final original = List<VehicleSummary>.of(fleet);

        final layout = buildFleetMarkerLayout(
          vehicles: fleet,
          camera: camera,
          cluster: true,
        );

        _expectConservedLayout(layout, fleetSize);
        expect(layout.groups.any((group) => group.isCluster), isTrue);
        expect(fleet, orderedEquals(original));
        expect(fleet.length, fleetSize);
        for (final group in layout.groups.where((group) => group.isCluster)) {
          expect(group.vehicle, isNull);
        }
      });

      test(
          '$fleetSize dense vehicles stay bounded at zoom 19 with clusters off',
          () {
        final camera = _camera(zoom: 19);
        final fleet = List.generate(
          fleetSize,
          (index) => _vehicle('$index', camera.center),
        );

        final layout = buildFleetMarkerLayout(
          vehicles: fleet,
          camera: camera,
          cluster: false,
        );

        _expectConservedLayout(layout, fleetSize);
        expect(layout.groups, hasLength(1));
        expect(layout.groups.single.count, fleetSize);
        expect(layout.groups.single.vehicle, isNull);
        expect(fleet.length, fleetSize);
      });

      test('$fleetSize distributed vehicles stay bounded at street zoom', () {
        final camera = _camera(zoom: 19, width: 1600, height: 1000);
        final fleet = _distributedFleet(camera, fleetSize);

        final layout = buildFleetMarkerLayout(
          vehicles: fleet,
          camera: camera,
          cluster: false,
        );

        _expectConservedLayout(layout, fleetSize);
      });
    }

    test('selected vehicle stays individual while all dense counts survive',
        () {
      final camera = _camera(zoom: 19);
      final fleet = List.generate(
        5000,
        (index) => _vehicle('$index', camera.center),
      );
      final selected = fleet[4321];

      final layout = buildFleetMarkerLayout(
        vehicles: fleet,
        camera: camera,
        cluster: false,
        selectedVehicleKey: fleetVehicleKey(selected),
      );

      _expectConservedLayout(layout, 5000);
      final selectedGroup = layout.groups.singleWhere(
        (group) => group.key == fleetVehicleKey(selected),
      );
      expect(selectedGroup.isCluster, isFalse);
      expect(selectedGroup.count, 1);
      expect(selectedGroup.vehicle, same(selected));
      expect(
          layout.groups.where((group) => group.isCluster).single.count, 4999);
    });

    test(
        'small visible fleet retains individual markers when clustering is off',
        () {
      final camera = _camera(zoom: 19);
      final fleet = _distributedFleet(camera, 100);
      final layout = buildFleetMarkerLayout(
        vehicles: fleet,
        camera: camera,
        cluster: false,
      );

      _expectConservedLayout(layout, 100);
      expect(layout.groups.every((group) => !group.isCluster), isTrue);
      expect(layout.groups.map((group) => group.vehicle), orderedEquals(fleet));
    });
  });

  group('Fleet viewport changes', () {
    test('pan, rotation and resize recalculate the visible fleet', () {
      final camera = _camera(width: 400, height: 600);
      final fleet = [
        _vehicle('center', _atPixelOffset(camera, 0, 0)),
        _vehicle('rotated', _atPixelOffset(camera, 330, 0)),
        _vehicle('wide', _atPixelOffset(camera, 580, 0)),
        _vehicle('panned', _atPixelOffset(camera, 1000, 0)),
        _vehicle('panned-edge', _atPixelOffset(camera, 1200, 0)),
      ];

      final initial = _layout(fleet, camera);
      expect(_individualIds(initial), ['center']);

      final rotated = _layout(
        fleet,
        _camera(width: 400, height: 600, rotation: 45),
      );
      expect(_individualIds(rotated), ['center', 'rotated']);

      final resized = _layout(fleet, _camera(width: 1000, height: 600));
      expect(_individualIds(resized), ['center', 'rotated', 'wide']);

      final panned = _layout(
        fleet,
        _camera(
          center: _atPixelOffset(camera, 1000, 0),
          width: 400,
          height: 600,
        ),
      );
      expect(_individualIds(panned), ['panned', 'panned-edge']);
      _expectConservedLayout(initial, 1);
      _expectConservedLayout(rotated, 2);
      _expectConservedLayout(resized, 3);
      _expectConservedLayout(panned, 2);
      expect(fleet.length, 5);
    });

    test('offscreen vehicles are retained in fleet but do not allocate groups',
        () {
      final camera = _camera();
      final visible = _vehicle('visible', camera.center);
      final offscreen = List.generate(
        9999,
        (index) => _vehicle('offscreen-$index', const LatLng(-30, -70)),
      );
      final fleet = [visible, ...offscreen];

      final layout = buildFleetMarkerLayout(
        vehicles: fleet,
        camera: camera,
        cluster: true,
        selectedVehicleKey: fleetVehicleKey(offscreen.last),
      );

      _expectConservedLayout(layout, 1);
      expect(layout.groups.single.vehicle, same(visible));
      expect(fleet.length, 10000);
      expect(fleet.last, same(offscreen.last));
    });

    test('overscan retains marker edges without admitting distant vehicles',
        () {
      final camera = _camera(width: 400, height: 600);
      final fleet = [
        _vehicle('edge', _atPixelOffset(camera, 250, 0)),
        _vehicle('outside', _atPixelOffset(camera, 350, 0)),
      ];

      final layout = _layout(fleet, camera);

      expect(_individualIds(layout), ['edge']);
      _expectConservedLayout(layout, 1);
    });

    test('invalid coordinates and locations are excluded before projection',
        () {
      final camera = _camera();
      final fleet = [
        _vehicle('valid', camera.center),
        _vehicle('flag-invalid', camera.center)
            .copyWith(hasValidLocation: false),
        _vehicle('latitude-range', const LatLng(91, 77)),
        _vehicle('longitude-range', const LatLng(28, 181)),
        _vehicle('nan', const LatLng(double.nan, 77)),
        _vehicle('infinite', const LatLng(28, double.infinity)),
      ];

      final layout = _layout(fleet, camera);

      expect(_individualIds(layout), ['valid']);
      _expectConservedLayout(layout, 1);
      expect(fleet.length, 6);
    });

    test('camera without layout size does not render markers', () {
      for (final size in [
        const math.Point<double>(0, 600),
        const math.Point<double>(400, 0),
        MapCamera.kImpossibleSize,
      ]) {
        final camera = _camera(width: size.x, height: size.y);
        final layout = _layout([_vehicle('1', camera.center)], camera);
        expect(layout.groups, isEmpty);
        expect(layout.visibleVehicleCount, 0);
      }
    });
  });

  test('repeatable 10000 vehicle load probe over 200 viewport plans', () {
    final originalCamera = _camera(zoom: 19, width: 1200, height: 900);
    final fleet = _distributedFleet(originalCamera, 10000);
    final sourceIds =
        fleet.map((vehicle) => vehicle.id).toList(growable: false);
    final cameras = List.generate(200, (index) {
      final angle = index * math.pi / 25;
      return _camera(
        zoom: 19,
        center: _atPixelOffset(
          originalCamera,
          math.sin(angle) * 140,
          math.cos(angle) * 100,
        ),
        rotation: (index % 8) * 15,
        width: index.isEven ? 1200 : 600,
        height: index.isEven ? 900 : 700,
      );
    });
    var totalVisible = 0;
    var maximumGroups = 0;
    final stopwatch = Stopwatch()..start();

    for (final camera in cameras) {
      final layout = buildFleetMarkerLayout(
        vehicles: fleet,
        camera: camera,
        cluster: false,
      );
      _expectConservedLayout(layout, layout.visibleVehicleCount);
      expect(layout.visibleVehicleCount, greaterThan(0));
      totalVisible += layout.visibleVehicleCount;
      maximumGroups = math.max(maximumGroups, layout.groups.length);
    }

    stopwatch.stop();
    expect(fleet.length, 10000);
    expect(fleet.map((vehicle) => vehicle.id), orderedEquals(sourceIds));
    // Report a reproducible workload without hardware-dependent timing gates.
    // ignore: avoid_print
    print(
      'Fleet layout probe: 200 plans / 10000 retained vehicles / '
      '$totalVisible visible observations / max $maximumGroups groups / '
      '${stopwatch.elapsedMilliseconds} ms total.',
    );
  });
}

MapCamera _camera({
  LatLng center = const LatLng(28.6139, 77.2090),
  double zoom = 11,
  double width = 400,
  double height = 800,
  double rotation = 0,
}) =>
    MapCamera(
      crs: const Epsg3857(),
      center: center,
      zoom: zoom,
      rotation: rotation,
      nonRotatedSize: math.Point(width, height),
    );

LatLng _atPixelOffset(MapCamera camera, double x, double y) {
  final center = camera.project(camera.center);
  return camera.unproject(math.Point(center.x + x, center.y + y));
}

VehicleSummary _vehicle(String id, LatLng location) => VehicleSummary(
      id: id,
      imei: 'imei-$id',
      name: 'Vehicle $id',
      plateNumber: 'Plate $id',
      status: 'running',
      speed: 32,
      latitude: location.latitude,
      longitude: location.longitude,
    );

List<VehicleSummary> _distributedFleet(MapCamera camera, int count) {
  final columns = math.sqrt(count).ceil();
  final rows = (count / columns).ceil();
  return List.generate(count, (index) {
    final x = ((index % columns) / (columns - 1) - 0.5) *
        (camera.nonRotatedSize.x - 40);
    final y = ((index ~/ columns) / (rows - 1) - 0.5) *
        (camera.nonRotatedSize.y - 40);
    return _vehicle('$index', _atPixelOffset(camera, x, y));
  });
}

FleetMarkerLayout _layout(List<VehicleSummary> fleet, MapCamera camera) =>
    buildFleetMarkerLayout(vehicles: fleet, camera: camera, cluster: false);

List<String> _individualIds(FleetMarkerLayout layout) =>
    layout.groups.map((group) => group.vehicle!.id).toList(growable: false);

void _expectConservedLayout(FleetMarkerLayout layout, int visibleCount) {
  expect(layout.visibleVehicleCount, visibleCount);
  expect(layout.groups.length, lessThanOrEqualTo(maxFleetMapMarkers));
  expect(
    layout.groups.fold<int>(0, (count, group) => count + group.count),
    visibleCount,
  );
  expect(layout.groups.every((group) => group.count >= 1), isTrue);
  expect(
    layout.groups.map((group) => group.key).toSet().length,
    layout.groups.length,
  );
}
