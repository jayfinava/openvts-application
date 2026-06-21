import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../models/user_vehicle_state.dart';

/// Pill-shaped segmented control for filtering vehicles by status.
///
/// Features:
/// * Black background with white border
/// * Selected segment: black background with white border
/// * Unselected segment: transparent background
/// * Optional count badges showing vehicle counts per status
/// * All text and icons in white for dark mode consistency
class UserVehicleStatusSegment extends StatelessWidget {
  const UserVehicleStatusSegment({
    required this.current,
    required this.onChanged,
    this.counts,
    super.key,
  });

  final UserVehicleStatusFilter current;
  final ValueChanged<UserVehicleStatusFilter> onChanged;
  final Map<UserVehicleStatusFilter, int>? counts;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        border: Border.all(
          color: isDark ? Colors.white : Colors.black.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          for (final filter in UserVehicleStatusFilter.values)
            Expanded(
              child: _Segment(
                filter: filter,
                selected: current == filter,
                count: counts?[filter],
                isDark: isDark,
                onTap: () => onChanged(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.filter,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.count,
  });

  final UserVehicleStatusFilter filter;
  final bool selected;
  final bool isDark;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : Colors.black;
    final selectedBg = isDark ? Colors.black : Colors.white;
    final selectedBorder = isDark ? Colors.white : Colors.black;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OpenVtsSpacing.xs,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
            border: selected ? Border.all(color: selectedBorder) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (filter.icon != null) ...[
                Icon(
                  filter.icon,
                  size: 14,
                  color: textColor,
                ),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  filter.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenVtsTypography.label.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                _Badge(
                  text: count.toString(),
                  isDark: isDark,
                  selected: selected,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.text,
    required this.isDark,
    required this.selected,
  });

  final String text;
  final bool isDark;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : Colors.black;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: OpenVtsTypography.meta.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}

extension UserVehicleStatusFilterX on UserVehicleStatusFilter {
  String get label {
    return switch (this) {
      UserVehicleStatusFilter.all => 'All',
      UserVehicleStatusFilter.active => 'Active',
      UserVehicleStatusFilter.inactive => 'Inactive',
      UserVehicleStatusFilter.licenseBlocked => 'License Blocked',
    };
  }

  IconData? get icon {
    return switch (this) {
      UserVehicleStatusFilter.all => Icons.check_circle_outline,
      UserVehicleStatusFilter.active => Icons.check_circle,
      UserVehicleStatusFilter.inactive => Icons.cancel_outlined,
      UserVehicleStatusFilter.licenseBlocked => Icons.block_outlined,
    };
  }
}
