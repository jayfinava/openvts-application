import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../models/admin_logs_model.dart';
import '../models/admin_logs_state.dart';
import '../services/admin_logs_service.dart';

class AdminLogsController extends StateNotifier<AdminLogsState> {
  AdminLogsController({required AdminLogsService service})
      : _service = service,
        super(const AdminLogsState.initial()) {
    unawaited(loadInitial());
  }

  final AdminLogsService _service;

  Future<void> loadInitial() async {
    await loadOptions();
    await loadActivityLogs();
  }

  Future<void> selectTab(AdminLogsTab tab) async {
    state = state.copyWith(selectedTab: tab, sectionErrorMessage: null);
    if (tab == AdminLogsTab.vehicle &&
        state.vehicleLogs.isEmpty &&
        !state.isLoadingVehicle) {
      await loadVehicleLogs();
    }
    if (tab == AdminLogsTab.telemetry &&
        state.telemetryLogs.isEmpty &&
        !state.isLoadingTelemetry) {
      await loadTelemetryLogs();
    }
  }

  Future<void> refreshCurrentTab() async {
    switch (state.selectedTab) {
      case AdminLogsTab.activity:
        await loadActivityLogs();
      case AdminLogsTab.vehicle:
        await loadVehicleLogs();
      case AdminLogsTab.telemetry:
        await loadTelemetryLogs();
    }
  }

  Future<void> loadOptions() async {
    state = state.copyWith(isLoadingOptions: true, errorMessage: null);
    try {
      final options = await _service.getOptions();
      state = state.copyWith(isLoadingOptions: false, options: options);
    } catch (e) {
      state =
          state.copyWith(isLoadingOptions: false, errorMessage: _toError(e));
    }
  }

  Future<void> loadActivityLogs() async {
    state = state.copyWith(
      isLoadingActivity: true,
      sectionErrorMessage: null,
      activityNextCursorId: null,
      activityHasMore: false,
    );
    try {
      final page = await _service.getActivityLogs(
        limit: 20,
        q: state.activitySearch,
        userId: state.activityUserId,
        actionPrefix: state.activityActionPrefix,
        entity: state.activityEntity,
        from: _fmt(state.activityFrom),
        to: _fmt(state.activityTo),
      );
      state = state.copyWith(
        isLoadingActivity: false,
        activityLogs: page.items,
        activityNextCursorId: page.nextCursorId,
        activityHasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingActivity: false,
        sectionErrorMessage: _toError(e),
      );
    }
  }

  Future<void> loadMoreActivityLogs() async {
    if (!state.activityHasMore ||
        state.isLoadingMoreActivity ||
        state.isLoadingActivity) {
      return;
    }
    state = state.copyWith(isLoadingMoreActivity: true);
    try {
      final page = await _service.getActivityLogs(
        limit: 20,
        cursorId: state.activityNextCursorId,
        q: state.activitySearch,
        userId: state.activityUserId,
        actionPrefix: state.activityActionPrefix,
        entity: state.activityEntity,
        from: _fmt(state.activityFrom),
        to: _fmt(state.activityTo),
      );
      state = state.copyWith(
        isLoadingMoreActivity: false,
        activityLogs: <AdminActivityLogItem>[
          ...state.activityLogs,
          ...page.items
        ],
        activityNextCursorId: page.nextCursorId,
        activityHasMore: page.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMoreActivity: false,
        sectionErrorMessage: _toError(e),
      );
    }
  }

  Future<void> loadVehicleLogs() async {
    state = state.copyWith(
      isLoadingVehicle: true,
      sectionErrorMessage: null,
      vehicleNextCursorId: null,
    );
    try {
      final now = DateTime.now();
      final fromDefault = now.subtract(const Duration(hours: 24));
      final page = await _service.getVehicleEventLogs(
        limit: 50,
        from: _fmt(state.vehicleFrom ?? fromDefault),
        to: _fmt(state.vehicleTo),
        vehicleId: state.vehicleVehicleId,
        userId: state.vehicleUserId,
        source: state.vehicleSource,
        severity: state.vehicleSeverity,
        q: state.vehicleSearch,
        dedupe: state.vehicleDedupe,
      );
      final filtered = _applyReadFilter(page.items, state.vehicleReadFilter);
      state = state.copyWith(
        isLoadingVehicle: false,
        vehicleLogs: filtered,
        vehicleNextCursorId: page.nextCursorId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingVehicle: false,
        sectionErrorMessage: _toError(e),
      );
    }
  }

  Future<void> loadMoreVehicleLogs() async {
    if (state.isLoadingMoreVehicle ||
        state.isLoadingVehicle ||
        (state.vehicleNextCursorId ?? '').isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingMoreVehicle: true);
    try {
      final now = DateTime.now();
      final fromDefault = now.subtract(const Duration(hours: 24));
      final page = await _service.getVehicleEventLogs(
        limit: 50,
        cursorId: state.vehicleNextCursorId,
        from: _fmt(state.vehicleFrom ?? fromDefault),
        to: _fmt(state.vehicleTo),
        vehicleId: state.vehicleVehicleId,
        userId: state.vehicleUserId,
        source: state.vehicleSource,
        severity: state.vehicleSeverity,
        q: state.vehicleSearch,
        dedupe: state.vehicleDedupe,
      );
      final filtered = _applyReadFilter(page.items, state.vehicleReadFilter);
      state = state.copyWith(
        isLoadingMoreVehicle: false,
        vehicleLogs: <AdminVehicleEventLogItem>[
          ...state.vehicleLogs,
          ...filtered
        ],
        vehicleNextCursorId: page.nextCursorId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMoreVehicle: false,
        sectionErrorMessage: _toError(e),
      );
    }
  }

  Future<void> loadTelemetryLogs() async {
    state = state.copyWith(
      isLoadingTelemetry: true,
      sectionErrorMessage: null,
      telemetryNextCursor: null,
    );
    try {
      final now = DateTime.now();
      final fromDefault = now.subtract(const Duration(hours: 1));
      final page = await _service.getTelemetryLogs(
        limit: 200,
        from: _fmt(state.telemetryFrom ?? fromDefault),
        to: _fmt(state.telemetryTo),
        vehicleId: state.telemetryVehicleId,
        imei: state.telemetryImeiSearch,
        packetType: state.telemetryPacketType,
      );
      state = state.copyWith(
        isLoadingTelemetry: false,
        telemetryLogs: page.items,
        telemetryNextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingTelemetry: false,
        sectionErrorMessage: _toError(e),
      );
    }
  }

  Future<void> loadMoreTelemetryLogs() async {
    if (state.isLoadingMoreTelemetry ||
        state.isLoadingTelemetry ||
        (state.telemetryNextCursor ?? '').isEmpty) {
      return;
    }
    state = state.copyWith(isLoadingMoreTelemetry: true);
    try {
      final now = DateTime.now();
      final fromDefault = now.subtract(const Duration(hours: 1));
      final page = await _service.getTelemetryLogs(
        limit: 200,
        beforeId: state.telemetryNextCursor,
        from: _fmt(state.telemetryFrom ?? fromDefault),
        to: _fmt(state.telemetryTo),
        vehicleId: state.telemetryVehicleId,
        imei: state.telemetryImeiSearch,
        packetType: state.telemetryPacketType,
      );
      state = state.copyWith(
        isLoadingMoreTelemetry: false,
        telemetryLogs: <AdminTelemetryLogItem>[
          ...state.telemetryLogs,
          ...page.items
        ],
        telemetryNextCursor: page.nextCursor,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMoreTelemetry: false,
        sectionErrorMessage: _toError(e),
      );
    }
  }

  void setActivityFilters({
    String? userId,
    String? actionPrefix,
    String? entity,
    String? search,
    DateTime? from,
    DateTime? to,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    state = state.copyWith(
      activityUserId: userId ?? state.activityUserId,
      activityActionPrefix: actionPrefix ?? state.activityActionPrefix,
      activityEntity: entity ?? state.activityEntity,
      activitySearch: search ?? state.activitySearch,
      activityFrom: clearFrom ? null : from ?? state.activityFrom,
      activityTo: clearTo ? null : to ?? state.activityTo,
      activityLogs: const <AdminActivityLogItem>[],
      activityNextCursorId: null,
      activityHasMore: false,
    );
  }

  void setVehicleFilters({
    String? vehicleId,
    String? userId,
    String? source,
    String? severity,
    AdminReadFilter? readFilter,
    String? search,
    DateTime? from,
    DateTime? to,
    bool? dedupe,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    state = state.copyWith(
      vehicleVehicleId: vehicleId ?? state.vehicleVehicleId,
      vehicleUserId: userId ?? state.vehicleUserId,
      vehicleSource: source ?? state.vehicleSource,
      vehicleSeverity: severity ?? state.vehicleSeverity,
      vehicleReadFilter: readFilter ?? state.vehicleReadFilter,
      vehicleSearch: search ?? state.vehicleSearch,
      vehicleFrom: clearFrom ? null : from ?? state.vehicleFrom,
      vehicleTo: clearTo ? null : to ?? state.vehicleTo,
      vehicleDedupe: dedupe ?? state.vehicleDedupe,
      vehicleLogs: const <AdminVehicleEventLogItem>[],
      vehicleNextCursorId: null,
    );
  }

  void setTelemetryFilters({
    String? vehicleId,
    String? packetType,
    String? imeiSearch,
    DateTime? from,
    DateTime? to,
    AdminReadFilter? readFilter,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    state = state.copyWith(
      telemetryVehicleId: vehicleId ?? state.telemetryVehicleId,
      telemetryPacketType: packetType ?? state.telemetryPacketType,
      telemetryImeiSearch: imeiSearch ?? state.telemetryImeiSearch,
      telemetryFrom: clearFrom ? null : from ?? state.telemetryFrom,
      telemetryTo: clearTo ? null : to ?? state.telemetryTo,
      telemetryReadFilter: readFilter ?? state.telemetryReadFilter,
      telemetryLogs: const <AdminTelemetryLogItem>[],
      telemetryNextCursor: null,
    );
  }

  Future<AdminVehicleEventDetail> getVehicleEventDetail(String id) async {
    final detail = await _service.getVehicleEventDetail(id);

    if (!detail.isRead) {
      try {
        await _service.markVehicleEventAsRead(id);

        final updatedLogs = state.vehicleLogs.map((item) {
          if (item.id == id) {
            return item.copyWith(isRead: true);
          }
          return item;
        }).toList();

        state = state.copyWith(vehicleLogs: updatedLogs);
      } catch (e) {
        // Silently ignore mark-as-read failures to avoid blocking the UI
      }
    }

    return detail;
  }

  Future<AdminTelemetryDetail> getTelemetryDetail(String id) {
    return _service.getTelemetryDetail(id);
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '';
    return dt.toUtc().toIso8601String();
  }

  List<AdminVehicleEventLogItem> _applyReadFilter(
    List<AdminVehicleEventLogItem> items,
    AdminReadFilter filter,
  ) {
    switch (filter) {
      case AdminReadFilter.all:
        return [...items];
      case AdminReadFilter.read:
        return items.where((item) => item.isReadNormalized).toList();
      case AdminReadFilter.unread:
        return items.where((item) => !item.isReadNormalized).toList();
    }
  }

  String _toError(Object e) {
    if (e is ApiException) return e.message;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['message'] ??
            (data['data'] is Map ? (data['data'] as Map)['message'] : null);
        if (msg is String && msg.trim().isNotEmpty) return msg.trim();
      }
      final m = e.message?.trim();
      if (m != null && m.isNotEmpty) return m;
    }
    return 'Unable to load vehicle events.';
  }
}
