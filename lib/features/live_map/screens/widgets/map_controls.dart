part of '../live_map_screen.dart';

class _SingleVehicleTrackingStatus extends StatelessWidget {
  const _SingleVehicleTrackingStatus({
    required this.vehicle,
    required this.isConnected,
  });

  final VehicleSummary? vehicle;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final vehicle = this.vehicle;
    final fixTime = vehicle?.locationServerTime;
    final detail = vehicle == null
        ? context.mobileText('Waiting for vehicle…')
        : vehicle.licenseBlocked
            ? context.mobileText('Tracking unavailable: license blocked')
            : vehicle.serviceBlocked
                ? context.mobileText('Tracking unavailable: service blocked')
                : vehicle.imei.trim().isEmpty
                    ? context.mobileText('No tracking device assigned')
                    : fixTime == null
                        ? vehicle.hasValidLocation
                            ? context.mobileText('GPS timestamp unavailable')
                            : context.mobileText('Waiting for GPS location')
                        : '${context.mobileText('Last GPS')}: ${DateFormat('d MMM, HH:mm:ss').format(fixTime.toLocal())}';
    return Material(
      color: scheme.surface,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        key: const ValueKey('single-vehicle-tracking-status'),
        constraints: BoxConstraints(
          minHeight: 54,
          maxWidth: math.min(
            280,
            math.max(120, MediaQuery.sizeOf(context).width - 88),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: isConnected
                  ? context.mobileText('Live connection connected')
                  : context.mobileText('Live tracking reconnecting…'),
              child: Icon(
                isConnected ? Icons.sensors_rounded : Icons.sync_rounded,
                size: 20,
                color: isConnected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle == null
                        ? context.mobileText('Vehicle tracking')
                        : _vehicleDisplayName(vehicle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapTelemetryFilters extends StatelessWidget {
  const _MapTelemetryFilters({
    required this.selectedFilter,
    required this.allCount,
    required this.runningCount,
    required this.stopCount,
    required this.inactiveCount,
    required this.onSelected,
  });

  final _MapFilter selectedFilter;
  final int allCount;
  final int runningCount;
  final int stopCount;
  final int inactiveCount;
  final ValueChanged<_MapFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TelemetryCircleButton(
          label: context.mobileText('All'),
          count: allCount,
          isSelected: selectedFilter == _MapFilter.all,
          onTap: () => onSelected(_MapFilter.all),
        ),
        const SizedBox(width: 6),
        _TelemetryCircleButton(
          label: context.mobileText('Running'),
          count: runningCount,
          isSelected: selectedFilter == _MapFilter.running,
          onTap: () => onSelected(_MapFilter.running),
        ),
        const SizedBox(width: 6),
        _TelemetryCircleButton(
          label: context.mobileText('Stop'),
          count: stopCount,
          isSelected: selectedFilter == _MapFilter.stop,
          onTap: () => onSelected(_MapFilter.stop),
        ),
        const SizedBox(width: 6),
        _TelemetryCircleButton(
          label: context.mobileText('Inactive'),
          count: inactiveCount,
          isSelected: selectedFilter == _MapFilter.inactive,
          onTap: () => onSelected(_MapFilter.inactive),
        ),
      ],
    );
  }
}

class _TelemetryCircleButton extends StatelessWidget {
  const _TelemetryCircleButton({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: isSelected ? scheme.onSurface : scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? scheme.onSurface : scheme.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? scheme.surface : scheme.onSurface,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? scheme.surface.withValues(alpha: 0.92)
                      : scheme.onSurfaceVariant,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDrawerButton extends StatelessWidget {
  const _BottomDrawerButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: scheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.keyboard_arrow_up_rounded,
            size: 22,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
