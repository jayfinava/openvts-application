import 'package:flutter/material.dart';

import '../../../core/theme/open_vts_radius.dart';
import '../../../core/theme/open_vts_spacing.dart';
import '../../../core/theme/open_vts_typography.dart';

/// Compact metric header section for dashboard row layouts.
///
/// Typically used in 2-column grids with label and value.
class OpenVtsDashboardHeader extends StatelessWidget {
  const OpenVtsDashboardHeader({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: OpenVtsTypography.meta.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: OpenVtsTypography.numeric.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact metric pill for inline display.
///
/// Shows label + value in a compact bordered container.
class OpenVtsDashboardMetricPill extends StatelessWidget {
  const OpenVtsDashboardMetricPill({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OpenVtsSpacing.xs,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(OpenVtsRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: OpenVtsSpacing.xxs),
          ],
          Text(
            label,
            style: OpenVtsTypography.meta.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: OpenVtsSpacing.xxs),
          Text(
            value,
            style: OpenVtsTypography.meta.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact status pill for displaying status/state.
///
/// Compact display with icon and label in bordered container.
class OpenVtsDashboardStatusPill extends StatelessWidget {
  const OpenVtsDashboardStatusPill({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final int value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(OpenVtsRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: OpenVtsSpacing.xxs),
          ],
          Text(
            label,
            style: OpenVtsTypography.meta.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: OpenVtsSpacing.xxs),
          Text(
            value.toString(),
            style: OpenVtsTypography.meta.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
