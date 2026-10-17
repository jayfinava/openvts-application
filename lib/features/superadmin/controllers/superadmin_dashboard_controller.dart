import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/error_mapper.dart';
import '../models/superadmin_dashboard_model.dart';
import '../models/superadmin_dashboard_state.dart';
import '../services/superadmin_dashboard_service.dart';

class SuperadminDashboardController
    extends StateNotifier<SuperadminDashboardState> {
  SuperadminDashboardController(this._service)
      : super(const SuperadminDashboardState.initial()) {
    load();
  }

  final SuperadminDashboardService _service;
  int _generation = 0;

  Future<void> load({bool refresh = false}) async {
    if (!mounted) return;
    final generation = ++_generation;
    final hasData = state.hasData;

    state = state.copyWith(
      isInitialLoading: !hasData,
      isRefreshing: hasData || refresh,
      isLoadingMore: false,
      errorMessage: null,
    );

    try {
      final dashboard = await _service.getDashboard();
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        dashboard: dashboard,
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: null,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isInitialLoading: false,
        isRefreshing: false,
        isLoadingMore: false,
        errorMessage: _toErrorMessage(error),
      );
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final actorId = state.selectedActorId;
    final fromDate = state.fromDate;
    final toDate = state.toDate;

    await load(refresh: true);

    if (actorId != null || fromDate != null || toDate != null) {
      await applyFilters(actorId: actorId, from: fromDate, to: toDate);
    }
  }

  Future<void> applyFilters({
    int? actorId,
    DateTime? from,
    DateTime? to,
  }) async {
    if (!mounted) return;
    final current = state.dashboard;
    if (current == null) {
      await load();
      return;
    }

    final generation = ++_generation;
    state = state.copyWith(
      selectedActorId: actorId,
      isLoadingMore: false,
      fromDate: from,
      toDate: to,
      isRefreshing: true,
      errorMessage: null,
    );

    try {
      final response = await _service.fetchActivityLogs(
        limit: SuperadminDashboardService.activityLogPageSize,
        actorId: actorId,
        from: from,
        to: to,
        refreshKey: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      final activityPage = SuperadminActivityLogPage.fromJson(response);
      if (!mounted || generation != _generation) return;

      state = state.copyWith(
        dashboard: current.copyWith(activityLogs: activityPage),
        isRefreshing: false,
        errorMessage: null,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isRefreshing: false,
        errorMessage: _toErrorMessage(error),
      );
    }
  }

  Future<void> clearFilters() {
    return applyFilters();
  }

  void toggleMetricVisibility(String metric) {
    final updated = {...state.visibleMetrics};
    if (updated.contains(metric)) {
      if (updated.length > 1) {
        updated.remove(metric);
      }
    } else {
      updated.add(metric);
    }
    state = state.copyWith(visibleMetrics: updated);
  }

  Future<void> loadMoreActivityLogs() async {
    if (!mounted || state.isRefreshing) return;
    final generation = _generation;
    final current = state.dashboard;
    final nextCursorId = current?.activityLogs.nextCursorId;

    if (current == null ||
        state.isInitialLoading ||
        state.isLoadingMore ||
        nextCursorId == null ||
        nextCursorId <= 0) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, errorMessage: null);

    try {
      final response = await _service.fetchActivityLogs(
        limit: SuperadminDashboardService.activityLogPageSize,
        cursorId: nextCursorId,
        actorId: state.selectedActorId,
        from: state.fromDate,
        to: state.toDate,
      );
      final activityPage = SuperadminActivityLogPage.fromJson(response);
      if (!mounted || generation != _generation) return;

      state = state.copyWith(
        dashboard: current.copyWith(
          activityLogs: current.activityLogs.copyWith(
            items: _mergeActivityLogs(
              current.activityLogs.items,
              activityPage.items,
            ),
            nextCursorId: activityPage.nextCursorId,
          ),
        ),
        isLoadingMore: false,
        errorMessage: null,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: _toErrorMessage(error),
      );
    }
  }

  List<SuperadminActivityLog> _mergeActivityLogs(
    List<SuperadminActivityLog> current,
    List<SuperadminActivityLog> incoming,
  ) {
    final merged = <String, SuperadminActivityLog>{
      for (final log in current) log.id: log,
    };

    for (final log in incoming) {
      final key = log.id.isEmpty
          ? '${log.title}-${log.actorName}-${log.createdAt?.millisecondsSinceEpoch ?? 0}'
          : log.id;
      merged[key] = log;
    }

    final values = merged.values.toList(growable: false)
      ..sort(
        (left, right) =>
            (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
          left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    return values;
  }

  String _toErrorMessage(Object error) => ErrorMapper.from(error).message;
}
