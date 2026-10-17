import 'package:dio/dio.dart';

import '../../../core/access/workspace_scope_provider.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_options.dart';
import '../../../core/api/api_response.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/models/vehicle_summary.dart';
import '../../notifications/models/app_notification.dart';
import '../../superadmin/models/superadmin_map_overlay_model.dart';
import '../../superadmin/models/superadmin_vehicle_history_model.dart';
import '../../superadmin/models/superadmin_vehicle_model.dart';
import '../../superadmin/services/superadmin_map_overlay_service.dart';
import '../../superadmin/services/superadmin_vehicle_service.dart';
import '../models/live_map_role_config.dart';
import '../models/live_map_vehicle_target.dart';

// ---------------------------------------------------------------------------
// Role-neutral model aliases.
//
// The Superadmin Map parsers are battle-tested. Instead of duplicating ~3.7k
// lines of model + parser code, we expose them under role-neutral names via
// typedefs so the Admin/User maps can speak `LiveMapTelemetry` etc., while
// the underlying classes (and JSON parsing rules) stay byte-identical.
// ---------------------------------------------------------------------------
typedef LiveMapTelemetry = SuperadminMapTelemetry;
typedef LiveMapVehicleDetails = SuperadminVehicleDetails;
typedef LiveMapVehicleLogPage = SuperadminVehicleLogPage;
typedef LiveMapVehicleLog = SuperadminVehicleLog;
typedef LiveMapVehicleEventPage = SuperadminVehicleEventPage;
typedef LiveMapVehicleSensorPage = SuperadminVehicleSensorPage;
typedef LiveMapVehicleHistory = SuperadminVehicleHistory;
typedef LiveMapVehicleHistoryRequest = SuperadminVehicleHistoryRequest;
typedef LiveMapVehicleReplay = SuperadminVehicleReplay;
typedef LiveMapCustomCommand = SuperadminCustomCommand;
typedef LiveMapSystemVariable = SuperadminSystemVariable;
typedef LiveMapSendCommandResult = SuperadminSendCommandResult;
typedef LiveMapCommandHistoryPage = SuperadminCommandHistoryPage;
typedef LiveMapCommandHistoryItem = SuperadminCommandHistoryItem;
typedef LiveMapCommandStatus = SuperadminCommandStatus;

/// Shared role-aware live-map service.
///
/// Holds a [LiveMapRoleConfig] for endpoint resolution and delegates JSON
/// parsing to the proven Superadmin parsers. Every API call goes through
/// the role-scoped endpoint from [_config] — there is no path to leak a
/// superadmin endpoint into an admin/user session.
class LiveMapVehicleService {
  Map<String, dynamic>? _targetMetricsRow;
  LiveMapVehicleService({
    required ApiClient apiClient,
    required LiveMapRoleConfig config,
  })  : _apiClient = apiClient,
        _config = config,
        _parsers = SuperadminVehicleService(apiClient),
        _overlayParsers = SuperadminMapOverlayService(apiClient);

  final ApiClient _apiClient;
  final CancelToken _lifetimeToken = CancelToken();
  final LiveMapRoleConfig _config;
  // Used purely as a parser host — no methods on these instances that hit
  // a hard-coded superadmin endpoint are ever invoked from this class.
  final SuperadminVehicleService _parsers;
  final SuperadminMapOverlayService _overlayParsers;

  LiveMapRoleConfig get config => _config;
  LiveMapRole get role => _config.role;

  static final Options _readOptions = normalReadOptions();

  void dispose() => _lifetimeToken.cancel('Map scope closed');

  Future<ApiResponse<T>> _get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    required T Function(dynamic json) parser,
  }) =>
      _apiClient.get<T>(
        endpoint,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken ?? _lifetimeToken,
        parser: parser,
      );

  // -------------------------------------------------------------------------
  // Parser passthroughs (used by LiveMapController for socket payload merge).
  // -------------------------------------------------------------------------

  LiveMapTelemetry parseMapTelemetryPayload(dynamic json) {
    return _parsers.parseMapTelemetryPayload(json);
  }

  VehicleSummary? parseTelemetryVehiclePayload(
    dynamic raw, {
    bool requireCoordinates = false,
  }) {
    return _parsers.parseTelemetryVehiclePayload(
      raw,
      requireCoordinates: requireCoordinates,
    );
  }

  LiveMapTelemetry buildTelemetryFromVehicles(List<VehicleSummary> vehicles) {
    return _parsers.buildTelemetryFromVehicles(vehicles);
  }

  SuperadminVehicleLog? parseTelemetryLogPayload(dynamic raw) {
    return _parsers.parseTelemetryLogPayload(raw);
  }

  List<SuperadminVehicleLog> parseTelemetryLogListPayload(dynamic raw) {
    return _parsers.parseTelemetryLogListPayload(raw);
  }

  AppNotification? parseVehicleEventPayload(dynamic raw, {String? imei}) {
    return _parsers.parseVehicleEventPayload(raw, imei: imei);
  }

  List<String> resolveVehicleIdentityAliases(
    dynamic raw, {
    VehicleSummary? fallbackVehicle,
  }) {
    return _parsers.resolveVehicleIdentityAliases(
      raw,
      fallbackVehicle: fallbackVehicle,
    );
  }

  List<String> resolveVehicleIdentityAliasesForVehicle(VehicleSummary vehicle) {
    return _parsers.resolveVehicleIdentityAliasesForVehicle(vehicle);
  }

  // -------------------------------------------------------------------------
  // Map telemetry
  // -------------------------------------------------------------------------

  Future<LiveMapTelemetry> getMapTelemetry({
    String? refreshKey,
    CancelToken? cancelToken,
    LiveMapVehicleTarget? target,
  }) async {
    if (AppConfig.useMockData) {
      // Mock data lives inside SuperadminVehicleService; route through it
      // for parity with current Superadmin behavior.
      return _parsers.getMapTelemetry(refreshKey: refreshKey);
    }

    if (target != null && _config.socketAuthenticationRequired) {
      return _getTargetTelemetry(target, cancelToken: cancelToken);
    }

    return _parsers.loadMapTelemetryEndpoint(
      _config.mapTelemetryEndpoint,
      refreshKey: refreshKey,
      cancelToken: cancelToken ?? _lifetimeToken,
    );
  }

  /// The current backend exposes a direct authorized vehicle lookup. Opening
  /// a tracking link must not paginate the fleet just to retain one row.
  Future<LiveMapTelemetry> _getTargetTelemetry(
    LiveMapVehicleTarget target, {
    CancelToken? cancelToken,
  }) async {
    final scope = workspaceDataScope(_apiClient.activeUser,
        isDemo: _apiClient.isDemoMode);
    void checkScope() {
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
      if (_lifetimeToken.isCancelled) throw _lifetimeToken.cancelError!;
      if (workspaceDataScope(_apiClient.activeUser,
              isDemo: _apiClient.isDemoMode) !=
          scope) {
        throw StateError('Map access changed while loading the vehicle.');
      }
    }

    final id = target.vehicleId.trim();
    final imei = target.imei.trim();
    if (id.isEmpty && imei.isEmpty) return buildTelemetryFromVehicles([]);
    try {
      final response = await _get<Map<String, dynamic>>(
        id.isNotEmpty
            ? '/map/v2/vehicles/${Uri.encodeComponent(id)}'
            : '/map/v2/locate',
        queryParameters: id.isEmpty ? {'imei': imei} : null,
        options: _readOptions,
        cancelToken: cancelToken,
        parser: (json) {
          final data = _unwrapMapData(json);
          if (data['row'] is! Map) {
            throw const FormatException('Missing vehicle row');
          }
          return Map<String, dynamic>.from(data['row'] as Map);
        },
      );
      checkScope();
      final row = response.data;
      final state = row['state'] is Map
          ? Map<String, dynamic>.from(row['state'] as Map)
          : <String, dynamic>{};
      final blocked = row['canViewLive'] != true ||
          row['isLicenseBlocked'] == true ||
          (row['service'] is Map &&
              (row['service'] as Map)['liveAllowed'] == false);
      var vehicle = parseTelemetryVehiclePayload({
        ...row,
        'state': state['status'] ?? row['status'],
        'telemetry': blocked ? null : state,
        'latitude': blocked ? null : state['latitude'],
        'longitude': blocked ? null : state['longitude'],
        'serviceBlocked': blocked,
      });
      if (vehicle == null || !target.matchesVehicle(vehicle)) {
        throw const FormatException('The server returned a different vehicle');
      }
      // map-v2 projects the authorized last known position. Its current GPS
      // quality fields must not hide that position (e.g. a device indoors).
      final latitude = state['latitude'];
      final longitude = state['longitude'];
      if (!blocked &&
          latitude is num &&
          longitude is num &&
          latitude.isFinite &&
          longitude.isFinite &&
          latitude.abs() <= 90 &&
          longitude.abs() <= 180 &&
          !(latitude == 0 && longitude == 0)) {
        vehicle = vehicle.copyWith(hasValidLocation: true);
      }
      _targetMetricsRow = blocked ? null : row;
      if (blocked || vehicle.imei.isEmpty) {
        return buildTelemetryFromVehicles([vehicle]);
      }

      return buildTelemetryFromVehicles([vehicle]);
    } on DioException catch (error) {
      checkScope();
      if (error.response?.statusCode == 404) {
        return buildTelemetryFromVehicles([]);
      }
      rethrow;
    }
  }

  /// Optional analytics are separate from the GPS baseline and socket startup.
  Future<VehicleSummary?> getTargetMetrics(VehicleSummary vehicle,
      {CancelToken? cancelToken}) async {
    final row = _targetMetricsRow;
    if (row == null ||
        vehicle.imei.isEmpty ||
        vehicle.serviceBlocked ||
        vehicle.licenseBlocked ||
        row['id'].toString() != vehicle.id ||
        row['imei'] != vehicle.imei) {
      return null;
    }
    final scope = workspaceDataScope(_apiClient.activeUser,
        isDemo: _apiClient.isDemoMode);
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayKey = '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final response = await _get<Map<String, dynamic>>('/map/v2/metrics',
        queryParameters: {
          'ids': vehicle.id,
          'dayKey': dayKey,
          'dayStart': dayStart.toUtc().toIso8601String()
        },
        cancelToken: cancelToken,
        options: lowPriorityOptions(),
        parser: _unwrapMapData);
    if (scope !=
            workspaceDataScope(_apiClient.activeUser,
                isDemo: _apiClient.isDemoMode) ||
        !identical(row, _targetMetricsRow)) {
      return null;
    }
    final rows = response.data['rows'];
    if (rows is! List) return null;
    for (final metric in rows.whereType<Map>()) {
      if (metric['vehicleId'].toString() != vehicle.id ||
          metric['imei'] != vehicle.imei ||
          metric['bindingVersion'] != row['bindingVersion'] ||
          metric['serviceRevision'] != row['serviceRevision'] ||
          metric['metricsAvailable'] != true ||
          metric['telemetry'] is! Map) {
        continue;
      }
      return parseTelemetryVehiclePayload({
        ...row,
        'telemetry': {
          ...(row['state'] as Map? ?? {}),
          ...metric['telemetry'] as Map
        }
      });
    }
    return null;
  }

  static Map<String, dynamic> _unwrapMapData(dynamic input) {
    dynamic value = input;
    for (var depth = 0;
        depth < 3 && value is Map && value['data'] is Map;
        depth++) {
      value = value['data'];
    }
    if (value is! Map) throw const FormatException('Invalid map response');
    return Map<String, dynamic>.from(value);
  }

  // -------------------------------------------------------------------------
  // Vehicle drilldown
  // -------------------------------------------------------------------------

  Future<LiveMapVehicleDetails> getVehicleDetailsByImei(String imei) async {
    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      return const SuperadminVehicleDetails.empty();
    }

    if (AppConfig.useMockData) {
      return _parsers.getVehicleDetailsByImei(normalizedImei);
    }

    final response = await _get<LiveMapVehicleDetails>(
      _config.vehicleDetailsByImei(normalizedImei),
      options: _readOptions,
      parser: _parsers.parseVehicleDetailsPayload,
    );
    return response.data;
  }

  Future<LiveMapVehicleLogPage> getVehicleLogsByImei(
    String imei, {
    int limit = 100,
    String? beforeId,
  }) async {
    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      return const SuperadminVehicleLogPage(items: <SuperadminVehicleLog>[]);
    }

    final normalizedLimit = limit < 1
        ? 100
        : limit > 500
            ? 500
            : limit;
    final normalizedCursor = beforeId?.trim() ?? '';

    if (AppConfig.useMockData) {
      return _parsers.getVehicleLogsByImei(
        normalizedImei,
        limit: normalizedLimit,
        beforeId: normalizedCursor.isEmpty ? null : normalizedCursor,
      );
    }

    final response = await _get<LiveMapVehicleLogPage>(
      _config.vehicleLogsByImei(normalizedImei),
      queryParameters: <String, dynamic>{
        'limit': normalizedLimit,
        if (normalizedCursor.isNotEmpty) 'beforeId': normalizedCursor,
      },
      options: _readOptions,
      parser: _parsers.parseVehicleLogsPayload,
    );
    return response.data;
  }

  Future<LiveMapVehicleEventPage> getVehicleEventsByImei(
    String imei, {
    int limit = 50,
    String? beforeId,
  }) async {
    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      return const SuperadminVehicleEventPage(items: <AppNotification>[]);
    }

    final normalizedLimit = limit < 1
        ? 50
        : limit > 300
            ? 300
            : limit;
    final normalizedCursor = beforeId?.trim() ?? '';

    if (AppConfig.useMockData) {
      return _parsers.getVehicleEventsByImei(
        normalizedImei,
        limit: normalizedLimit,
        beforeId: normalizedCursor.isEmpty ? null : normalizedCursor,
      );
    }

    final response = await _get<LiveMapVehicleEventPage>(
      _config.vehicleEventsByImei(normalizedImei),
      queryParameters: <String, dynamic>{
        'limit': normalizedLimit,
        if (normalizedCursor.isNotEmpty) 'beforeId': normalizedCursor,
      },
      options: _readOptions,
      parser: (json) => _parsers.parseVehicleEventsPayload(
        json,
        imei: normalizedImei,
        requestedLimit: normalizedLimit,
      ),
    );
    return response.data;
  }

  Future<LiveMapVehicleSensorPage> getVehicleSensorsByImei(String imei) async {
    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      return const SuperadminVehicleSensorPage(
        items: <SuperadminVehicleSensor>[],
        totalCount: 0,
      );
    }

    if (AppConfig.useMockData) {
      return _parsers.getVehicleSensorsByImei(normalizedImei);
    }

    final response = await _get<LiveMapVehicleSensorPage>(
      _config.vehicleSensorsByImei(normalizedImei),
      queryParameters: const <String, dynamic>{'includeTelemetryMeta': 'true'},
      options: _readOptions,
      parser: _parsers.parseVehicleSensorsPayload,
    );
    return response.data;
  }

  /// History fetch using the existing [LiveMapVehicleHistoryRequest] shape, so
  /// the shared [LiveMapVehicleHistoryController] can call this exactly the
  /// same way the legacy Superadmin history controller did.
  Future<LiveMapVehicleHistory> getVehicleHistory(
    LiveMapVehicleHistoryRequest request, {
    int maxPoints = 5000,
    CancelToken? cancelToken,
  }) async {
    return getVehicleHistoryByImei(
      imei: request.imei,
      from: request.from,
      to: request.to,
      stopMin: request.stopMinutes,
      maxPoints: maxPoints,
      cancelToken: cancelToken,
    );
  }

  Future<LiveMapVehicleHistory> getVehicleHistoryByImei({
    required String imei,
    required DateTime from,
    required DateTime to,
    int stopMin = 5,
    int maxPoints = 5000,
    int? overspeedKph,
    CancelToken? cancelToken,
  }) async {
    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      throw ArgumentError('Vehicle IMEI is required to load history.');
    }

    final normalizedFrom = from.isAfter(to) ? to : from;
    final normalizedTo = to.isBefore(from) ? from : to;
    final normalizedStopMin = stopMin < 1 ? 1 : stopMin;
    final normalizedMaxPoints = maxPoints < 1 ? 1 : maxPoints;

    final request = SuperadminVehicleHistoryRequest(
      vehicle: VehicleSummaryShim.forImei(normalizedImei),
      from: normalizedFrom,
      to: normalizedTo,
      stopMinutes: normalizedStopMin,
    );

    final response = await _get<LiveMapVehicleHistory>(
      _config.vehicleHistoryByImei(normalizedImei),
      queryParameters: <String, dynamic>{
        'from': normalizedFrom.toUtc().toIso8601String(),
        'to': normalizedTo.toUtc().toIso8601String(),
        'stopMin': normalizedStopMin.toString(),
        'maxPoints': normalizedMaxPoints.toString(),
        if (overspeedKph != null) 'overspeedKph': overspeedKph.toString(),
      },
      options: heavyReadOptions(),
      cancelToken: cancelToken,
      parser: (json) => _parsers.parseVehicleHistoryPayload(json, request),
    );
    return response.data;
  }

  Future<LiveMapVehicleReplay> getVehicleReplayByImei({
    required String imei,
    required DateTime from,
    required DateTime to,
    int maxPoints = 5000,
    CancelToken? cancelToken,
  }) async {
    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      throw ArgumentError('Vehicle IMEI is required to load replay.');
    }

    if (AppConfig.useMockData) {
      return _parsers.getVehicleReplayByImei(
        imei: normalizedImei,
        from: from,
        to: to,
        maxPoints: maxPoints,
      );
    }

    final response = await _get<LiveMapVehicleReplay>(
      _config.vehicleReplayByImei(normalizedImei),
      queryParameters: <String, dynamic>{
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'maxPoints': maxPoints,
      },
      options: heavyReadOptions(),
      cancelToken: cancelToken,
      parser: _parsers.parseVehicleReplayPayload,
    );
    return response.data;
  }

  // -------------------------------------------------------------------------
  // Overlays — only when the role config opts in.
  // -------------------------------------------------------------------------

  Future<List<SuperadminMapGeofence>> getGeofences({String? refreshKey}) async {
    final endpoint = _config.geofencesEndpoint;
    if (!_config.supportsGeofence || endpoint == null) {
      throw StateError(
        'Geofences are not enabled for role ${_config.role.name}.',
      );
    }

    final response = await _get<List<SuperadminMapGeofence>>(
      endpoint,
      queryParameters: <String, dynamic>{
        'rk': refreshKey ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: _readOptions,
      parser: _overlayParsers.parseGeofencesPayload,
    );
    return response.data;
  }

  Future<List<SuperadminMapPoi>> getPois({String? refreshKey}) async {
    final endpoint = _config.poisEndpoint;
    if (!_config.supportsPoi || endpoint == null) {
      throw StateError('POIs are not enabled for role ${_config.role.name}.');
    }

    final response = await _get<List<SuperadminMapPoi>>(
      endpoint,
      queryParameters: <String, dynamic>{
        'rk': refreshKey ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: _readOptions,
      parser: _overlayParsers.parsePoisPayload,
    );
    return response.data;
  }

  Future<List<SuperadminMapRoute>> getRoutes({String? refreshKey}) async {
    final endpoint = _config.routesEndpoint;
    if (!_config.supportsRoute || endpoint == null) {
      throw StateError('Routes are not enabled for role ${_config.role.name}.');
    }

    final response = await _get<List<SuperadminMapRoute>>(
      endpoint,
      queryParameters: <String, dynamic>{
        'includeGeodata': true,
        'rk': refreshKey ?? DateTime.now().millisecondsSinceEpoch.toString(),
      },
      options: _readOptions,
      parser: _overlayParsers.parseRoutesPayload,
    );
    return response.data;
  }

  // -------------------------------------------------------------------------
  // Commands
  // -------------------------------------------------------------------------

  Future<List<LiveMapCustomCommand>> getCustomCommands({
    int? deviceTypeId,
    bool activeOnly = true,
  }) async {
    final endpoint = _config.customCommandsEndpoint;
    if (endpoint == null) {
      throw StateError(
        'Custom commands are not enabled for role ${_config.role.name}.',
      );
    }

    if (AppConfig.useMockData) {
      return _parsers.getCustomCommands(
        deviceTypeId: deviceTypeId,
        activeOnly: activeOnly,
      );
    }

    final response = await _get<List<LiveMapCustomCommand>>(
      endpoint,
      queryParameters: <String, dynamic>{
        'activeOnly': activeOnly,
        if (deviceTypeId != null) 'deviceTypeId': deviceTypeId.toString(),
      },
      options: _readOptions,
      parser: _parsers.parseCustomCommandsPayload,
    );
    return response.data;
  }

  Future<List<LiveMapSystemVariable>> getSystemVariables() async {
    final endpoint = _config.systemVariablesEndpoint;
    if (endpoint == null) {
      throw StateError(
        'System variables are not enabled for role ${_config.role.name}.',
      );
    }

    if (AppConfig.useMockData) {
      return _parsers.getSystemVariables();
    }

    final response = await _get<List<LiveMapSystemVariable>>(
      endpoint,
      options: _readOptions,
      parser: _parsers.parseSystemVariablesPayload,
    );
    return response.data;
  }

  /// Superadmin/Admin command flow.
  Future<LiveMapSendCommandResult> sendCommandByImei({
    required String imei,
    required String command,
    String? note,
  }) async {
    if (_config.commandSendMode != LiveMapCommandSendMode.byImei) {
      throw StateError(
        'sendCommandByImei is not supported for role ${_config.role.name}; '
        'use sendBulkCommandForUserVehicles instead.',
      );
    }
    final builder = _config.sendCommandByImei;
    if (builder == null) {
      throw StateError(
        'sendCommandByImei endpoint missing for role ${_config.role.name}.',
      );
    }

    final normalizedImei = imei.trim();
    final normalizedCommand = command.trim();
    if (normalizedImei.isEmpty) {
      throw ArgumentError('Vehicle IMEI is required to send a command.');
    }
    if (normalizedCommand.isEmpty) {
      throw ArgumentError('Command text is required.');
    }
    if (normalizedCommand.length > 500) {
      throw ArgumentError('Command text must be 500 characters or less.');
    }

    if (AppConfig.useMockData) {
      return _parsers.sendCommandByImei(
        imei: normalizedImei,
        command: normalizedCommand,
        note: note,
      );
    }

    final response = await _apiClient.post<LiveMapSendCommandResult>(
      builder(normalizedImei),
      data: <String, dynamic>{'command': normalizedCommand},
      options: _readOptions,
      parser: _parsers.parseSendCommandResponsePayload,
    );
    return response.data;
  }

  /// User bulk command flow — `POST /user/commands/send-bulk`.
  Future<LiveMapSendCommandResult> sendBulkCommandForUserVehicles({
    required List<String> vehicleIds,
    required String command,
  }) async {
    if (_config.commandSendMode != LiveMapCommandSendMode.bulkByVehicleId) {
      throw StateError(
        'sendBulkCommandForUserVehicles is not supported for role '
        '${_config.role.name}; use sendCommandByImei instead.',
      );
    }
    final endpoint = _config.userSendCommandBulkEndpoint;
    if (endpoint == null) {
      throw StateError(
        'Bulk send-command endpoint missing for role ${_config.role.name}.',
      );
    }

    final normalizedCommand = command.trim();
    final normalizedIds = <int>[];
    for (final rawId in vehicleIds) {
      final id = int.tryParse(rawId.trim());
      if (id == null || id <= 0) {
        throw ArgumentError('Vehicle IDs must be positive integers.');
      }
      if (!normalizedIds.contains(id)) normalizedIds.add(id);
    }
    if (normalizedIds.isEmpty) {
      throw ArgumentError('At least one vehicleId is required.');
    }
    if (normalizedCommand.isEmpty) {
      throw ArgumentError('Command text is required.');
    }
    if (normalizedCommand.length > 500) {
      throw ArgumentError('Command text must be 500 characters or less.');
    }

    final response = await _apiClient.post<Map<String, dynamic>>(
      endpoint,
      data: <String, dynamic>{
        'mode': 'SELECTED',
        'vehicleIds': normalizedIds,
        'command': normalizedCommand,
      },
      options: _readOptions,
      parser: (json) => json is Map
          ? json.map((key, value) => MapEntry(key.toString(), value))
          : const <String, dynamic>{},
    );
    final payload = response.data;
    final results = payload['results'];
    if (results is List) {
      if (results.isEmpty) {
        throw StateError('No command target was dispatched.');
      }
      for (final result in results) {
        if (result is Map &&
            result['error']?.toString().trim().isNotEmpty == true) {
          throw StateError(result['error'].toString());
        }
      }
      final first = results.first;
      if (first is! Map ||
          first['cmdId']?.toString().trim().isNotEmpty != true) {
        throw StateError(
          'The command response does not contain a dispatch ID.',
        );
      }
      return _parsers.parseSendCommandResponsePayload(first);
    }
    // Older installations return a single result directly.
    return _parsers.parseSendCommandResponsePayload(payload);
  }

  /// Per-IMEI command history (superadmin/admin).
  Future<LiveMapCommandHistoryPage> getCommandHistoryByImei({
    required String imei,
    int limit = 50,
    String? cursorId,
  }) async {
    final builder = _config.commandHistoryByImei;
    if (builder == null) {
      throw StateError(
        'commandHistoryByImei is not supported for role ${_config.role.name}; '
        'use getCommandHistoryByVehicleId instead.',
      );
    }

    final normalizedImei = imei.trim();
    if (normalizedImei.isEmpty) {
      return const SuperadminCommandHistoryPage(
        items: <SuperadminCommandHistoryItem>[],
      );
    }
    final normalizedLimit = limit < 1
        ? 50
        : limit > 100
            ? 100
            : limit;
    final normalizedCursor = cursorId?.trim() ?? '';

    if (AppConfig.useMockData) {
      return _parsers.getCommandHistoryByImei(
        imei: normalizedImei,
        limit: normalizedLimit,
        cursorId: normalizedCursor.isEmpty ? null : normalizedCursor,
      );
    }

    final response = await _get<LiveMapCommandHistoryPage>(
      builder(normalizedImei),
      queryParameters: <String, dynamic>{
        'limit': normalizedLimit,
        if (normalizedCursor.isNotEmpty) 'cursorId': normalizedCursor,
      },
      options: _readOptions,
      parser: _parsers.parseVehicleCommandsPayload,
    );
    return response.data;
  }

  /// Per-vehicleId command history (user).
  Future<LiveMapCommandHistoryPage> getCommandHistoryByVehicleId({
    required String vehicleId,
    int limit = 50,
    String? cursorId,
  }) async {
    final builder = _config.userCommandHistoryByVehicleId;
    if (builder == null) {
      throw StateError(
        'commandHistoryByVehicleId is not supported for role '
        '${_config.role.name}; use getCommandHistoryByImei instead.',
      );
    }

    final normalizedId = vehicleId.trim();
    if (normalizedId.isEmpty) {
      return const SuperadminCommandHistoryPage(
        items: <SuperadminCommandHistoryItem>[],
      );
    }
    final normalizedLimit = limit < 1
        ? 50
        : limit > 100
            ? 100
            : limit;
    final normalizedCursor = cursorId?.trim() ?? '';

    final response = await _get<LiveMapCommandHistoryPage>(
      builder(normalizedId),
      queryParameters: <String, dynamic>{
        'limit': normalizedLimit,
        if (normalizedCursor.isNotEmpty) 'cursorId': normalizedCursor,
      },
      options: _readOptions,
      parser: _parsers.parseVehicleCommandsPayload,
    );
    return response.data;
  }

  Future<LiveMapCommandStatus?> getCommandStatus(String cmdId) async {
    final builder = _config.commandStatusByCmdId;
    if (builder == null) {
      throw StateError(
        'commandStatus endpoint missing for role ${_config.role.name}.',
      );
    }

    final normalizedCmdId = cmdId.trim();
    if (normalizedCmdId.isEmpty) return null;

    if (AppConfig.useMockData) {
      return _parsers.getCommandStatus(normalizedCmdId);
    }

    final response = await _get<LiveMapCommandStatus?>(
      builder(normalizedCmdId),
      options: _readOptions,
      parser: _parsers.parseCommandStatusPayload,
    );
    return response.data;
  }

  Future<LiveMapCommandHistoryItem?> getCommandLogByCmdId(String cmdId) async {
    final builder = _config.commandLogByCmdId;
    if (builder == null) {
      throw StateError(
        'commandLog endpoint missing for role ${_config.role.name}.',
      );
    }

    final normalizedCmdId = cmdId.trim();
    if (normalizedCmdId.isEmpty) return null;

    if (AppConfig.useMockData) {
      return _parsers.getCommandLogByCmdId(normalizedCmdId);
    }

    final response = await _get<LiveMapCommandHistoryItem?>(
      builder(normalizedCmdId),
      options: _readOptions,
      parser: _parsers.parseCommandPayload,
    );
    return response.data;
  }

  /// Alias kept for parity with the legacy Superadmin service API.
  Future<LiveMapCommandHistoryItem?> getCommandDetail(String cmdId) {
    return getCommandLogByCmdId(cmdId);
  }
}

/// Internal helper — the Superadmin history parser needs a [VehicleSummary]
/// inside its request. The shared engine only knows the IMEI, so we build a
/// minimal placeholder used purely for downstream label fallback.
class VehicleSummaryShim {
  const VehicleSummaryShim._();

  static VehicleSummary forImei(String imei) {
    return VehicleSummary(
      id: imei,
      imei: imei,
      name: '',
      plateNumber: '',
      status: '',
      speed: 0,
      latitude: 0,
      longitude: 0,
      hasValidLocation: false,
    );
  }
}
