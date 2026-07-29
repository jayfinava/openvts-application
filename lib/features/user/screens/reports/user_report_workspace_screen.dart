import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/open_vts_colors.dart';
import '../../../../core/theme/open_vts_radius.dart';
import '../../../../core/theme/open_vts_spacing.dart';
import '../../../../core/theme/open_vts_typography.dart';
import '../../../../shared/widgets/open_vts_button.dart';
import '../../../../shared/widgets/open_vts_page_scaffold.dart';
import '../../controllers/user_report_workspace_notifier.dart';
import '../../controllers/user_providers.dart';
import '../../models/user_report_model.dart';
import '../../models/user_report_state.dart';
import '../../services/user_report_export_service.dart';
import 'widgets/filters/user_report_date_control.dart';
import 'widgets/filters/user_report_filters.dart';
import 'widgets/filters/user_report_vehicle_scope_selector.dart';
import 'widgets/user_report_state_views.dart';
import 'widgets/results/user_distance_report_result.dart';
import 'widgets/results/user_driven_report_result.dart';
import 'widgets/results/user_details_report_result.dart';
import 'widgets/results/user_overspeed_report_result.dart';
import 'widgets/results/user_geofence_report_result.dart';
import 'widgets/results/user_alerts_report_result.dart';
import 'widgets/results/user_sensor_report_result.dart';
import 'widgets/results/user_logs_report_result.dart';
import 'widgets/results/user_timeline_report_result.dart';

final _workspaceProvider = StateNotifierProvider.family.autoDispose<
    UserReportWorkspaceNotifier,
    UserReportWorkspaceState,
    UserReportKey>((ref, key) {
  final ctrl = ref.watch(userReportControllerProvider);
  return UserReportWorkspaceNotifier(initialKey: key, controller: ctrl);
});

class UserReportWorkspaceScreen extends ConsumerWidget {
  const UserReportWorkspaceScreen({required this.reportKey, super.key});

  final UserReportKey reportKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_workspaceProvider(reportKey));
    final notifier = ref.read(_workspaceProvider(reportKey).notifier);
    final title = _titleForKey(reportKey);

    return OpenVtsPageScaffold(
      title: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(OpenVtsSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter card
            _FilterSection(state: state, notifier: notifier),
            const SizedBox(height: OpenVtsSpacing.md),
            // Actions
            _ActionRow(state: state, notifier: notifier),
            const SizedBox(height: OpenVtsSpacing.md),
            // Result area
            _ResultArea(state: state, notifier: notifier),
          ],
        ),
      ),
    );
  }

  String _titleForKey(UserReportKey key) {
    return switch (key) {
      UserReportKey.distance => 'Distance',
      UserReportKey.driven => 'Driven Days',
      UserReportKey.details => 'Vehicle Details',
      UserReportKey.overspeed => 'Overspeed',
      UserReportKey.geofence => 'Geofence',
      UserReportKey.alerts => 'Alerts',
      UserReportKey.sensor => 'Sensor',
      UserReportKey.logs => 'Device Logs',
      UserReportKey.timeline => 'Timeline',
    };
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.state, required this.notifier});
  final UserReportWorkspaceState state;
  final UserReportWorkspaceNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final key = state.reportKey;
    final errors = state.validationErrors;
    final isLoading = state.genStatus == ReportGenStatus.loading;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
        border: Border.all(
            color: isDark ? OpenVtsColors.darkBorder : OpenVtsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                OpenVtsSpacing.sm, OpenVtsSpacing.sm, OpenVtsSpacing.sm, 0),
            child: Text('Filters',
                style: OpenVtsTypography.label
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(OpenVtsSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle scope
                UserReportVehicleScopeSelector(
                  scope: state.scope,
                  options: state.options ??
                      const UserReportOptions(vehicles: [], groups: []),
                  onScopeChanged: notifier.setScope,
                  forceSingle: key.requiresSingleVehicle,
                  disabled: isLoading,
                  error: errors['scope'],
                ),
                const SizedBox(height: OpenVtsSpacing.sm),
                // Date range
                UserReportDateControl(
                  reportKey: key,
                  dateRange: state.dateRange,
                  onChanged: notifier.setDateRange,
                  disabled: isLoading,
                  startError: errors['startDate'],
                  endError: errors['endDate'],
                  rangeError: errors['dateRange'],
                ),
                // Per-report filters
                if (_hasExtraFilters(key)) ...[
                  const SizedBox(height: OpenVtsSpacing.sm),
                  _ExtraFilters(
                      state: state, notifier: notifier, disabled: isLoading),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasExtraFilters(UserReportKey key) {
    return key != UserReportKey.distance &&
        key != UserReportKey.driven &&
        key != UserReportKey.details;
  }
}

class _ExtraFilters extends StatelessWidget {
  const _ExtraFilters(
      {required this.state, required this.notifier, required this.disabled});
  final UserReportWorkspaceState state;
  final UserReportWorkspaceNotifier notifier;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return switch (state.reportKey) {
      UserReportKey.overspeed => UserOverspeedReportFilter(
          filters: state.overspeedFilters,
          onChanged: notifier.setOverspeedFilters,
          disabled: disabled,
        ),
      UserReportKey.geofence => UserGeofenceReportFilter(
          filters: state.geofenceFilters,
          onChanged: notifier.setGeofenceFilters,
          geofences: state.geofences,
          disabled: disabled,
        ),
      UserReportKey.sensor => UserSensorReportFilter(
          vehicleId: state.scope.vehicleId,
          vehicles: state.options?.vehicles ?? const [],
          sensors: state.sensors,
          filters: state.sensorFilters,
          onVehicleChanged: (id) {
            if (id != null) {
              notifier.setScope(ReportVehicleScope.single(id));
              notifier.loadSensorsForVehicle(id);
            }
          },
          onFiltersChanged: notifier.setSensorFilters,
          disabled: disabled,
          vehicleError: state.validationErrors['sensorVehicle'],
          sensorError: state.validationErrors['sensorSensor'],
        ),
      UserReportKey.alerts => UserAlertsReportFilter(
          filters: state.alertsFilters,
          onChanged: notifier.setAlertsFilters,
          disabled: disabled,
        ),
      UserReportKey.logs => UserLogsReportFilter(
          vehicleId: state.scope.vehicleId,
          vehicles: state.options?.vehicles ?? const [],
          filters: state.logsFilters,
          onVehicleChanged: (id) {
            if (id != null) notifier.setScope(ReportVehicleScope.single(id));
          },
          onFiltersChanged: notifier.setLogsFilters,
          disabled: disabled,
        ),
      UserReportKey.timeline => UserTimelineReportFilter(
          filters: state.timelineFilters,
          onChanged: notifier.setTimelineFilters,
          disabled: disabled,
          error: state.validationErrors['timelineState'],
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state, required this.notifier});
  final UserReportWorkspaceState state;
  final UserReportWorkspaceNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final isLoading = state.genStatus == ReportGenStatus.loading;
    final hasResult = state.genStatus == ReportGenStatus.success ||
        state.genStatus == ReportGenStatus.empty;
    return Row(
      children: [
        Expanded(
          child: OpenVtsButton(
            label: isLoading ? 'Generating…' : 'Generate Report',
            onPressed: isLoading ? null : notifier.generate,
            isLoading: isLoading,
          ),
        ),
        if (hasResult) ...[
          const SizedBox(width: OpenVtsSpacing.sm),
          OutlinedButton.icon(
            onPressed: notifier.reset,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset'),
            style:
                OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
          ),
        ],
      ],
    );
  }
}

class _ResultArea extends StatelessWidget {
  const _ResultArea({required this.state, required this.notifier});
  final UserReportWorkspaceState state;
  final UserReportWorkspaceNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return switch (state.genStatus) {
      ReportGenStatus.initial => const ReportInitialView(),
      ReportGenStatus.loading => const ReportLoadingView(),
      ReportGenStatus.empty => const ReportEmptyView(),
      ReportGenStatus.error => ReportErrorView(
          message: state.genError ?? 'Unknown error',
          onRetry: notifier.generate),
      ReportGenStatus.success =>
        _ReportResult(state: state, notifier: notifier),
    };
  }
}

class _ReportResult extends StatelessWidget {
  const _ReportResult({required this.state, required this.notifier});
  final UserReportWorkspaceState state;
  final UserReportWorkspaceNotifier notifier;

  void _handleExport(BuildContext context, String format) {
    final exportService = UserReportExportService();
    exportService.export(
      reportKey: state.reportKey,
      rows: state.rows,
      allColumns: state.reportKey.preferredColumns,
      columnLabels: {},
      format: format,
      generatedAt: state.generatedAt,
      warning: state.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = state.reportKey;
    return switch (key) {
      UserReportKey.distance => UserDistanceReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.driven => UserDrivenReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.details => UserDetailsReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.overspeed => UserOverspeedReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.geofence => UserGeofenceReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.alerts => UserAlertsReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.sensor => UserSensorReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.logs => UserLogsReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
      UserReportKey.timeline => UserTimelineReportResult(
          state: state,
          onLoadMore: notifier.loadMore,
          onExport: (f) => _handleExport(context, f)),
    };
  }
}
