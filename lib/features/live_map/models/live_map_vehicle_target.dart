import '../../../shared/models/vehicle_summary.dart';

/// The vehicle selected before opening a map, resolved against authorized REST
/// membership. A device IMEI is only an identity fallback when no vehicle ID is
/// available; it must never select a different vehicle after reassignment.
class LiveMapVehicleTarget {
  const LiveMapVehicleTarget({required this.vehicleId, this.imei = ''});

  final String vehicleId;
  final String imei;

  String get identity {
    final id = vehicleId.trim();
    if (id.isNotEmpty) return 'id:$id';
    final device = imei.trim().toLowerCase();
    return device.isNotEmpty ? 'imei:$device' : 'vehicle:unavailable';
  }

  bool matchesVehicle(VehicleSummary vehicle) {
    final id = vehicleId.trim();
    if (id.isNotEmpty) return vehicle.id.trim() == id;
    final device = imei.trim().toLowerCase();
    return device.isNotEmpty && vehicle.imei.trim().toLowerCase() == device;
  }

  @override
  bool operator ==(Object other) =>
      other is LiveMapVehicleTarget && identity == other.identity;

  @override
  int get hashCode => identity.hashCode;
}
