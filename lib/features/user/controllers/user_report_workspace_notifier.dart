import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../../../core/platform/platform_time_zone.dart';
import '../models/user_report_model.dart';
import '../models/user_report_state.dart';
import '../utils/user_report_validation.dart';
import 'user_report_controller.dart';

/// StateNotifier for a single report workspace.
/// Handles options loading, generate, loadMore, reset.
/// Uses an incrementing requestToken to discard stale responses.
class UserReportWorkspaceNotifier
    extends StateNotifier<UserReportWorkspaceState> {
  UserReportWorkspaceNotifier({
    required UserReportKey initialKey,
    required UserReportController controller,
    Future<String> Function() resolveTimeZone = PlatformTimeZone.current,
  })  : _controller = controller,
        _resolveTimeZone = resolveTimeZone,
        super(UserReportWorkspaceState(
          reportKey: initialKey,
          dateRange: buildDefaultDateRange(initialKey),
          isLoadingOptions: true,
        )) {
    unawaited(_loadOptions());
  }

  final UserReportController _controller;
  final Future<String> Function() _resolveTimeZone;
  int _sensorRequestToken = 0;
  _GeneratedReportQuery? _generatedQuery;

  // ---------------------------------------------------------------------------
  // Options
  // ---------------------------------------------------------------------------

  Future<void> _loadOptions() async {
    state = state.copyWith(isLoadingOptions: true, clearOptionsError: true);
    try {
      final options = await _controller.getOptions();
      if (!mounted) return;
      state = state.copyWith(options: options, isLoadingOptions: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        isLoadingOptions: false,
        optionsError: _extractMessage(e),
      );
    }
  }

  Future<void> refreshOptions() => _loadOptions();

  // ---------------------------------------------------------------------------
  // Report key change
  // ---------------------------------------------------------------------------

  void changeReportKey(UserReportKey key) {
    if (key == state.reportKey) return;
    _sensorRequestToken++;
    _generatedQuery = null;
    state = UserReportWorkspaceState(
      requestToken: state.requestToken + 1,
      reportKey: key,
      options: state.options,
      optionsError: state.optionsError,
      isLoadingOptions: state.isLoadingOptions,
      scope: key.requiresSingleVehicle
          ? const ReportVehicleScope.single('')
          : state.scope.mode == ReportScopeMode.single
              ? const ReportVehicleScope.all()
              : state.scope,
      dateRange: buildDefaultDateRange(key),
      sensors: state.sensors,
      isLoadingSensors: state.isLoadingSensors,
      geofences: state.geofences,
      isLoadingGeofences: state.isLoadingGeofences,
    );
  }

  // ---------------------------------------------------------------------------
  // Scope / filter setters
  // ---------------------------------------------------------------------------

  void setScope(ReportVehicleScope scope) {
    final previousVehicleId = state.scope.vehicleId;
    final vehicleChanged = previousVehicleId != scope.vehicleId;
    state = state.copyWith(
      scope: scope,
      sensorFilters: state.reportKey == UserReportKey.sensor && vehicleChanged
          ? const SensorFilters()
          : state.sensorFilters,
      sensors: state.reportKey == UserReportKey.sensor && vehicleChanged
          ? const []
          : state.sensors,
      clearSensorLoadError: state.reportKey == UserReportKey.sensor,
    );
    if (scope.mode == ReportScopeMode.single &&
        scope.vehicleId != null &&
        scope.vehicleId!.isNotEmpty) {
      if (state.reportKey == UserReportKey.sensor && vehicleChanged) {
        unawaited(_loadSensors(scope.vehicleId!));
      }
    } else if (state.reportKey == UserReportKey.sensor && vehicleChanged) {
      _sensorRequestToken++;
    }
  }

  void setDateRange(ReportDateRange? range) {
    if (range == null) {
      state = state.copyWith(clearDateRange: true);
    } else {
      state = state.copyWith(dateRange: range);
    }
  }

  void setOverspeedFilters(OverspeedFilters f) =>
      state = state.copyWith(overspeedFilters: f);
  void setGeofenceFilters(GeofenceFilters f) =>
      state = state.copyWith(geofenceFilters: f);
  void setSensorFilters(SensorFilters f) =>
      state = state.copyWith(sensorFilters: f);
  void setAlertsFilters(AlertsFilters f) =>
      state = state.copyWith(alertsFilters: f);
  void setLogsFilters(LogsFilters f) => state = state.copyWith(logsFilters: f);
  void setTimelineFilters(TimelineFilters f) =>
      state = state.copyWith(timelineFilters: f);
  void clearValidationErrors() => state = state.copyWith(validationErrors: {});

  // ---------------------------------------------------------------------------
  // Sensors auxiliary
  // ---------------------------------------------------------------------------

  Future<void> _loadSensors(String vehicleId) async {
    final token = ++_sensorRequestToken;
    state = state.copyWith(
      isLoadingSensors: true,
      sensors: [],
      clearSensorLoadError: true,
    );
    try {
      final page = await _controller.getSensors(vehicleId);
      if (!mounted || token != _sensorRequestToken) return;
      if (state.reportKey != UserReportKey.sensor) return;
      if (state.scope.vehicleId != vehicleId) return;
      final sensors = page.items;
      state = state.copyWith(sensors: sensors, isLoadingSensors: false);
      // If previously selected sensor is no longer valid, clear it
      final currentId = state.sensorFilters.sensorIds.firstOrNull;
      if (currentId != null &&
          !sensors.any((s) => s.id.toString() == currentId)) {
        state = state.copyWith(sensorFilters: const SensorFilters());
      }
    } catch (e) {
      if (!mounted || token != _sensorRequestToken) return;
      if (state.reportKey != UserReportKey.sensor) return;
      if (state.scope.vehicleId != vehicleId) return;
      state = state.copyWith(
        isLoadingSensors: false,
        sensors: [],
        sensorLoadError: _extractMessage(e),
      );
    }
  }

  Future<void> retrySensorLoad() async {
    final vehicleId = state.scope.vehicleId;
    if (vehicleId == null || vehicleId.isEmpty) return;
    await _loadSensors(vehicleId);
  }

  // ---------------------------------------------------------------------------
  // Geofences auxiliary
  // ---------------------------------------------------------------------------

  Future<void> loadGeofences() async {
    if (state.geofences.isNotEmpty) return; // already loaded
    state = state.copyWith(isLoadingGeofences: true);
    try {
      final geofences = await _controller.getActiveGeofences();
      if (!mounted) return;
      state = state.copyWith(geofences: geofences, isLoadingGeofences: false);
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingGeofences: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Generate
  // ---------------------------------------------------------------------------

  Future<void> generate() async {
    if (state.genStatus == ReportGenStatus.loading) return;
    final s = state;
    final errors = validateReportQuery(
      reportKey: s.reportKey,
      scope: s.scope,
      dateRange: s.dateRange,
      overspeedFilters: s.overspeedFilters,
      sensorFilters: s.sensorFilters,
      timelineFilters: s.timelineFilters,
    );

    if (s.reportKey == UserReportKey.sensor) {
      final selectedIds = s.sensorFilters.sensorIds;
      final hasValidSelection = selectedIds.length == 1 &&
          s.sensors.any((sensor) => sensor.id.toString() == selectedIds.single);
      if (s.isLoadingSensors) {
        errors['sensorSensor'] = 'Wait for sensors to finish loading';
      } else if (!hasValidSelection) {
        errors['sensorSensor'] =
            'Select one sensor configured for this vehicle';
      }
      debugPrint(
        '[Reports][sensor] generate validationErrors=${errors.keys.toList()} '
        'vehicleId=${s.scope.vehicleId ?? 'none'} '
        'sensorId=${selectedIds.length == 1 ? selectedIds.single : 'invalid'}',
      );
    }

    if (errors.isNotEmpty) {
      state = state.copyWith(validationErrors: errors);
      return;
    }

    final token = s.requestToken + 1;
    _generatedQuery = null;
    state = state.copyWith(
      genStatus: ReportGenStatus.loading,
      rows: [],
      hasMore: false,
      clearNextCursor: true,
      clearWarning: true,
      clearSource: true,
      clearGenError: true,
      clearLoadMoreError: true,
      isLoadingMore: false,
      clearGeneratedAt: true,
      validationErrors: {},
      requestToken: token,
    );
    if (s.reportKey == UserReportKey.sensor) {
      debugPrint('[Reports][sensor] genStatus=loading');
    }

    try {
      final bounds = buildApiDateBounds(s.dateRange!);
      if (bounds == null) {
        state = state.copyWith(
            genStatus: ReportGenStatus.error, genError: 'Invalid date range');
        return;
      }
      final tz = await _resolveTimeZone();
      if (!mounted || state.requestToken != token) return;

      final query = _GeneratedReportQuery(
        reportKey: s.reportKey,
        vehicleScope: s.scope.toJson(),
        dateRange: s.dateRange!.toJson(),
        filters: _buildFilters(s),
        timeZone: tz,
        from: bounds.from,
        to: bounds.to,
      );
      final page = await _controller.generate(
        reportKey: query.reportKey,
        vehicleScope: query.vehicleScope,
        dateRange: query.dateRange,
        filters: query.filters,
        timeZone: query.timeZone,
        from: query.from,
        to: query.to,
      );

      if (!mounted || state.requestToken != token) return;

      _generatedQuery = query;
      state = state.copyWith(
        genStatus:
            page.rows.isEmpty ? ReportGenStatus.empty : ReportGenStatus.success,
        rows: page.rows,
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        warning: page.warning,
        source: page.source,
        generatedAt: page.generatedAt,
      );
      if (s.reportKey == UserReportKey.sensor) {
        debugPrint(
          '[Reports][sensor] genStatus=${state.genStatus.name} '
          'rows=${page.rows.length}',
        );
      }
    } catch (e) {
      if (!mounted || state.requestToken != token) return;
      state = state.copyWith(
          genStatus: ReportGenStatus.error, genError: _extractMessage(e));
      if (s.reportKey == UserReportKey.sensor) {
        debugPrint(
          '[Reports][sensor] genStatus=error error=${e.runtimeType}',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Load more
  // ---------------------------------------------------------------------------

  Future<void> loadMore() async {
    final s = state;
    final query = _generatedQuery;
    if (query == null ||
        !s.hasMore ||
        s.nextCursor == null ||
        s.isLoadingMore ||
        s.genStatus == ReportGenStatus.loading) {
      return;
    }

    final token = s.requestToken + 1;
    state = state.copyWith(
        isLoadingMore: true, clearLoadMoreError: true, requestToken: token);

    try {
      final page = await _controller.generate(
        reportKey: query.reportKey,
        vehicleScope: query.vehicleScope,
        dateRange: query.dateRange,
        filters: query.filters,
        timeZone: query.timeZone,
        from: query.from,
        to: query.to,
        cursor: s.nextCursor,
      );

      if (!mounted || state.requestToken != token) return;

      state = state.copyWith(
        isLoadingMore: false,
        rows: [...s.rows, ...page.rows],
        hasMore: page.hasMore,
        nextCursor: page.nextCursor,
        warning: page.warning,
      );
    } catch (e) {
      if (!mounted || state.requestToken != token) return;
      state = state.copyWith(
          isLoadingMore: false, loadMoreError: _extractMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Reset
  // ---------------------------------------------------------------------------

  void reset() {
    _sensorRequestToken++;
    _generatedQuery = null;
    final key = state.reportKey;
    state = UserReportWorkspaceState(
      requestToken: state.requestToken + 1,
      reportKey: key,
      options: state.options,
      optionsError: state.optionsError,
      isLoadingOptions: state.isLoadingOptions,
      dateRange: buildDefaultDateRange(key),
      scope: key.requiresSingleVehicle
          ? const ReportVehicleScope.single('')
          : const ReportVehicleScope.all(),
      geofences: state.geofences,
      isLoadingGeofences: state.isLoadingGeofences,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildFilters(UserReportWorkspaceState s) {
    return switch (s.reportKey) {
      UserReportKey.overspeed => s.overspeedFilters.toJson(),
      UserReportKey.geofence => s.geofenceFilters.toJson(),
      UserReportKey.sensor => s.sensorFilters.toJson(),
      UserReportKey.alerts => s.alertsFilters.toJson(),
      UserReportKey.logs => s.logsFilters.toJson(),
      UserReportKey.timeline => s.timelineFilters.toJson(),
      _ => <String, dynamic>{},
    };
  }

  String _extractMessage(Object error) => ErrorMapper.from(error).message;
}

/// Retains the submitted query for cursor requests, independently of draft
/// filters and later changes to the device's time zone.
class _GeneratedReportQuery {
  _GeneratedReportQuery({
    required this.reportKey,
    required Map<String, dynamic> vehicleScope,
    required Map<String, dynamic> dateRange,
    required Map<String, dynamic> filters,
    required this.timeZone,
    required this.from,
    required this.to,
  })  : vehicleScope = _freeze(vehicleScope),
        dateRange = _freeze(dateRange),
        filters = _freeze(filters);

  final UserReportKey reportKey;
  final Map<String, dynamic> vehicleScope;
  final Map<String, dynamic> dateRange;
  final Map<String, dynamic> filters;
  final String timeZone;
  final DateTime from;
  final DateTime to;

  static Map<String, dynamic> _freeze(Map<String, dynamic> values) =>
      Map.unmodifiable(values.map((key, value) => MapEntry(
            key,
            value is List ? List<dynamic>.unmodifiable(value) : value,
          )));
}
