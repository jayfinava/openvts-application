Map<String, dynamic> fleetEnvelope({int scene = 1, int interest = 1}) => {
      'protocolVersion': 2,
      'sessionId': 'session',
      'projectionEpoch': 'epoch',
      'scopeRevision': 'scope',
      'interestRevision': interest,
      'sceneRevision': scene,
      'asOf': 1,
    };

Map<String, dynamic> fleetWireVehicle(int id,
        {int revision = 1, DateTime? now}) =>
    {
      'id': 'v:$id',
      'kind': 'vehicle',
      'vehicleId': id,
      'imei': 'imei-$id',
      'vehicleName': 'Vehicle $id',
      'vehicleNumber': 'TEST $id',
      'vehicleTypeSlug': 'car',
      'bindingVersion': 1,
      'sourceRevision': '$revision',
      'entityRevision': revision,
      'latitude': 28.614 + id % 500 * 0.00001,
      'longitude': 77.209,
      'speedKph': 35.0,
      'course': 90.0,
      'status': 'running',
      'ignition': true,
      'serverTime': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'serverTimeMs': (now ?? DateTime.now()).millisecondsSinceEpoch,
      'serviceLiveUntil': (now ?? DateTime.now())
          .add(const Duration(days: 1))
          .toUtc()
          .toIso8601String(),
    };

Map<String, dynamic> fleetDirectoryRow(int id, {DateTime? now}) => {
      'id': id,
      'vehicleId': id,
      'name': 'Vehicle $id',
      'plateNumber': 'TEST $id',
      'imei': 'imei-$id',
      'bindingVersion': 1,
      'serviceRevision': 1,
      'canViewLive': true,
      'isLicenseBlocked': false,
      'service': {'liveAllowed': true},
      'state': fleetWireVehicle(id, now: now),
    };

Map<String, dynamic> fleetSummary(
        {int total = 5000, int scene = 1, int interest = 1}) =>
    {
      ...fleetEnvelope(scene: scene, interest: interest),
      'counts': {'all': total, 'running': total, 'stop': 0, 'inactive': 0},
      'bounds': [77.20, 28.61, 77.22, 28.63],
      'stale': false,
    };
