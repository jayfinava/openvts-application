import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';

/// The three top-level sections of the mobile Route Optimisation page.
enum RouteOptimisationTab { points, map, results }

extension RouteOptimisationTabX on RouteOptimisationTab {
  String get label {
    switch (this) {
      case RouteOptimisationTab.points:
        return 'Points';
      case RouteOptimisationTab.map:
        return 'Map';
      case RouteOptimisationTab.results:
        return 'Results';
    }
  }

  IconData get icon {
    switch (this) {
      case RouteOptimisationTab.points:
        return Icons.format_list_bulleted;
      case RouteOptimisationTab.map:
        return Icons.map_outlined;
      case RouteOptimisationTab.results:
        return Icons.insights_outlined;
    }
  }
}

/// Bordered, pill-shaped 3-segment control used as the mobile primary nav.
///
/// * Points segment shows a count badge.
/// * Results segment shows a small dot when a fresh result is available.
class RouteOptimisationMobileTabs extends StatelessWidget {
  const RouteOptimisationMobileTabs({
    required this.current,
    required this.onChanged,
    required this.pointCount,
    required this.hasResult,
    super.key,
  });

  final RouteOptimisationTab current;
  final ValueChanged<RouteOptimisationTab> onChanged;
  final int pointCount;
  final bool hasResult;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white : OpenVtsColors.border;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          for (final tab in RouteOptimisationTab.values)
            Expanded(
              child: _Segment(
                tab: tab,
                selected: current == tab,
                badge: switch (tab) {
                  RouteOptimisationTab.points =>
                    pointCount > 0 ? pointCount.toString() : null,
                  RouteOptimisationTab.results => hasResult ? '•' : null,
                  RouteOptimisationTab.map => null,
                },
                onTap: () => onChanged(tab),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.tab,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final RouteOptimisationTab tab;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segmentBgColor = selected
        ? (isDark ? Colors.black : OpenVtsColors.brandInk)
        : Colors.transparent;
    final segmentBorderColor = isDark ? Colors.white : OpenVtsColors.brandInk;
    final segmentTextColor = isDark
        ? Colors.white
        : (selected ? Colors.white : OpenVtsColors.brandInk);
    final segmentIconColor = isDark ? Colors.white : segmentTextColor;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OpenVtsSpacing.xs,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: segmentBgColor,
            borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
            border: selected ? Border.all(color: segmentBorderColor) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tab.icon, size: 14, color: segmentIconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenVtsTypography.label.copyWith(
                    color: segmentTextColor,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                _Badge(text: badge!, selected: selected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.selected});

  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDot = text == '•';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final badgeBgColor = isDot
        ? Colors.transparent
        : (isDark ? Colors.black : OpenVtsColors.brandInk);
    final badgeBorderColor = isDark ? Colors.white : OpenVtsColors.brandInk;

    return Container(
      padding: isDot
          ? const EdgeInsets.all(0)
          : const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: badgeBgColor,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        border: isDot ? null : Border.all(color: badgeBorderColor),
      ),
      child: Text(
        text,
        style: OpenVtsTypography.meta.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: isDot ? 16 : 11,
          height: 1,
        ),
      ),
    );
  }
}
