import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../models/user_support_model.dart';

/// Pill-shaped segmented control for filtering support tickets by status.
///
/// Features:
/// * Black background with white border in dark mode
/// * Selected segment: black background with white border
/// * Unselected segment: transparent background
/// * Optional count badges showing ticket counts per status
/// * All text and icons in white for dark mode consistency
class UserSupportStatusSegment extends StatelessWidget {
  const UserSupportStatusSegment({
    required this.selected,
    required this.onChanged,
    this.counts,
    super.key,
  });

  final UserSupportTicketStatus? selected;
  final ValueChanged<UserSupportTicketStatus?> onChanged;
  final Map<UserSupportTicketStatus?, int>? counts;

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
          Expanded(
            child: _Segment(
              label: 'All',
              icon: Icons.check_circle_outline,
              selected: selected == null,
              count: counts?[null],
              isDark: isDark,
              onTap: () => onChanged(null),
            ),
          ),
          for (final status in UserSupportTicketStatus.values)
            Expanded(
              child: _Segment(
                label: status.label,
                icon: status.icon,
                selected: selected == status,
                count: counts?[status],
                isDark: isDark,
                onTap: () => onChanged(status),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.count,
  });

  final String label;
  final IconData icon;
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
            horizontal: OpenVtsSpacing.xxs,
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
              Icon(
                icon,
                size: 13,
                color: textColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenVtsTypography.label.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 16, minHeight: 13),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Text(
        text,
        style: OpenVtsTypography.meta.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 10,
          height: 1,
        ),
      ),
    );
  }
}

extension _UserSupportTicketStatusIconX on UserSupportTicketStatus {
  IconData get icon {
    return switch (this) {
      UserSupportTicketStatus.open => Icons.chat_bubble_outline,
      UserSupportTicketStatus.inProgress => Icons.timelapse_outlined,
      UserSupportTicketStatus.closed => Icons.check_circle_outline,
    };
  }
}
