import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/vehicle_summary.dart';

/// A rendering budget, never a limit on the loaded or searchable fleet.
const maxFleetMapMarkers = 250;
const maxFleetAnimatedMarkers = 100;
const fleetMarkerOverscanPixels = 100.0;

bool hasRenderableFleetLocation(VehicleSummary vehicle) =>
    vehicle.hasValidLocation &&
    vehicle.latitude.isFinite &&
    vehicle.longitude.isFinite &&
    vehicle.latitude.abs() <= 90 &&
    vehicle.longitude.abs() <= 180;

String fleetVehicleKey(VehicleSummary vehicle) {
  final imei = vehicle.imei.trim().toLowerCase();
  if (imei.isNotEmpty) return 'imei:$imei';
  final id = vehicle.id.trim().toLowerCase();
  if (id.isNotEmpty) return 'id:$id';
  final plate = vehicle.plateNumber.trim().toLowerCase();
  if (plate.isNotEmpty) return 'plate:$plate';
  final name = vehicle.name.trim().toLowerCase();
  if (name.isNotEmpty) return 'name:$name';
  return 'location:${vehicle.latitude}:${vehicle.longitude}';
}

class FleetMarkerLayout {
  const FleetMarkerLayout({
    required this.groups,
    required this.visibleVehicleCount,
  });

  final List<FleetMarkerGroup> groups;
  final int visibleVehicleCount;
}

/// Only an individual marker retains a vehicle. Clusters retain a count and
/// bounds, avoiding another collection of the entire fleet in every layout.
class FleetMarkerGroup {
  const FleetMarkerGroup({
    required this.key,
    required this.count,
    required this.center,
    required this.bounds,
    required this.vehicle,
  });

  final String key;
  final int count;
  final LatLng center;
  final LatLngBounds bounds;
  final VehicleSummary? vehicle;
  bool get isCluster => count > 1;
}

/// Cull before constructing Flutter markers. Safety clustering also applies
/// with clustering disabled or at street zoom, so dense depots cannot create
/// thousands of elements, image layers and animation controllers.
FleetMarkerLayout buildFleetMarkerLayout({
  required List<VehicleSummary> vehicles,
  required MapCamera camera,
  required bool cluster,
  String? selectedVehicleKey,
}) {
  if (camera.nonRotatedSize.x <= 0 || camera.nonRotatedSize.y <= 0) {
    return const FleetMarkerLayout(groups: [], visibleVehicleCount: 0);
  }
  final bounds = camera.pixelBounds;
  final minX = bounds.min.x - fleetMarkerOverscanPixels;
  final maxX = bounds.max.x + fleetMarkerOverscanPixels;
  final minY = bounds.min.y - fleetMarkerOverscanPixels;
  final maxY = bounds.max.y + fleetMarkerOverscanPixels;
  final visible = <_ProjectedVehicle>[];
  _ProjectedVehicle? selected;
  for (final vehicle in vehicles) {
    if (!hasRenderableFleetLocation(vehicle)) continue;
    final point = camera.project(LatLng(vehicle.latitude, vehicle.longitude));
    if (!point.x.isFinite ||
        !point.y.isFinite ||
        point.x < minX ||
        point.x > maxX ||
        point.y < minY ||
        point.y > maxY) {
      continue;
    }
    final projected = _ProjectedVehicle(vehicle, point);
    if (selectedVehicleKey != null &&
        fleetVehicleKey(vehicle) == selectedVehicleKey) {
      selected = projected;
    } else {
      visible.add(projected);
    }
  }
  final count = visible.length + (selected == null ? 0 : 1);
  final budget = maxFleetMapMarkers - (selected == null ? 0 : 1);
  if ((!cluster || camera.zoom >= 16.5) && visible.length <= budget) {
    return FleetMarkerLayout(
      groups: [
        for (final point in visible) _single(point.vehicle),
        if (selected != null) _single(selected.vehicle),
      ],
      visibleVehicleCount: count,
    );
  }

  var cellSize = 72.0;
  Map<(int, int), _ClusterAccumulator> buckets;
  // Grow the grid until every visible vehicle fits in the rendering budget.
  // No truncation or sampling: the sum of group counts stays equal to count.
  do {
    buckets = {};
    for (final point in visible) {
      final cell = (
        (point.point.x / cellSize).floor(),
        (point.point.y / cellSize).floor(),
      );
      final existing = buckets[cell];
      if (existing == null) {
        buckets[cell] = _ClusterAccumulator(point);
      } else {
        existing.add(point);
      }
    }
    if (buckets.length > budget) cellSize *= 2;
  } while (buckets.length > budget);

  return FleetMarkerLayout(
    groups: [
      for (final entry in buckets.entries)
        entry.value.toGroup(camera, 'cluster:$cellSize:${entry.key}'),
      if (selected != null) _single(selected.vehicle),
    ],
    visibleVehicleCount: count,
  );
}

/// Apply the mobile widget budget to the server's weighted clusters as well
/// as individual vehicles. Counts are never sampled or truncated, even at
/// street zoom where the server can return many coincident leaves.
FleetMarkerLayout buildServerFleetMarkerLayout({
  required List<VehicleSummary> vehicles,
  required List<Map<String, dynamic>> clusters,
  required MapCamera camera,
  String? selectedVehicleKey,
}) {
  final local = buildFleetMarkerLayout(
      vehicles: vehicles,
      camera: camera,
      cluster: false,
      selectedVehicleKey: selectedVehicleKey);
  final groups = <FleetMarkerGroup>[...local.groups];
  for (final cluster in clusters) {
    final raw = cluster['bounds'];
    if (raw is! List || raw.length != 4) continue;
    groups.add(FleetMarkerGroup(
      key: 'server:${cluster['id']}',
      count: cluster['count'] as int,
      center: LatLng((cluster['latitude'] as num).toDouble(),
          (cluster['longitude'] as num).toDouble()),
      bounds: LatLngBounds(
          LatLng((raw[1] as num).toDouble(), (raw[0] as num).toDouble()),
          LatLng((raw[3] as num).toDouble(), (raw[2] as num).toDouble())),
      vehicle: null,
    ));
  }
  final count = groups.fold<int>(0, (sum, group) => sum + group.count);
  if (groups.length <= maxFleetMapMarkers) {
    return FleetMarkerLayout(groups: groups, visibleVehicleCount: count);
  }
  final selected = groups.where((g) => g.key == selectedVehicleKey).firstOrNull;
  final budget = maxFleetMapMarkers - (selected == null ? 0 : 1);
  var size = 72.0;
  Map<(int, int), List<FleetMarkerGroup>> buckets;
  do {
    buckets = {};
    for (final group in groups) {
      if (identical(group, selected)) continue;
      final point = camera.project(group.center);
      final key = ((point.x / size).floor(), (point.y / size).floor());
      (buckets[key] ??= []).add(group);
    }
    if (buckets.length > budget) size *= 2;
  } while (buckets.length > budget);
  return FleetMarkerLayout(groups: [
    for (final entry in buckets.entries)
      if (entry.value.length == 1)
        entry.value.single
      else
        _mergeGroups(entry.value, camera, 'merged:$size:${entry.key}'),
    if (selected != null) selected,
  ], visibleVehicleCount: count);
}

FleetMarkerGroup _mergeGroups(
    List<FleetMarkerGroup> groups, MapCamera camera, String key) {
  var count = 0, x = 0.0, y = 0.0;
  final bounds = LatLngBounds(
      groups.first.bounds.southWest, groups.first.bounds.northEast);
  for (final group in groups) {
    final point = camera.project(group.center);
    count += group.count;
    x += point.x * group.count;
    y += point.y * group.count;
    bounds.extendBounds(group.bounds);
  }
  return FleetMarkerGroup(
      key: key,
      count: count,
      center: camera.unproject(math.Point(x / count, y / count)),
      bounds: bounds,
      vehicle: null);
}

FleetMarkerGroup _single(VehicleSummary vehicle) {
  final point = LatLng(vehicle.latitude, vehicle.longitude);
  return FleetMarkerGroup(
    key: fleetVehicleKey(vehicle),
    count: 1,
    center: point,
    bounds: LatLngBounds(point, point),
    vehicle: vehicle,
  );
}

class _ProjectedVehicle {
  const _ProjectedVehicle(this.vehicle, this.point);
  final VehicleSummary vehicle;
  final math.Point<double> point;
}

class _ClusterAccumulator {
  _ClusterAccumulator(_ProjectedVehicle first)
      : vehicle = first.vehicle,
        x = first.point.x,
        y = first.point.y,
        south = first.vehicle.latitude,
        north = first.vehicle.latitude,
        west = first.vehicle.longitude,
        east = first.vehicle.longitude;

  final VehicleSummary vehicle;
  int count = 1;
  double x, y, south, north, west, east;

  void add(_ProjectedVehicle point) {
    count++;
    x += point.point.x;
    y += point.point.y;
    south = math.min(south, point.vehicle.latitude);
    north = math.max(north, point.vehicle.latitude);
    west = math.min(west, point.vehicle.longitude);
    east = math.max(east, point.vehicle.longitude);
  }

  FleetMarkerGroup toGroup(MapCamera camera, String key) {
    if (count == 1) return _single(vehicle);
    return FleetMarkerGroup(
      key: key,
      count: count,
      center: camera.unproject(math.Point(x / count, y / count)),
      bounds: LatLngBounds(LatLng(south, west), LatLng(north, east)),
      vehicle: null,
    );
  }
}
