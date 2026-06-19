import 'package:flutter/material.dart';

<<<<<<< HEAD
=======
import '../../../core/theme/open_vts_colors.dart';
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
import '../../../core/theme/open_vts_spacing.dart';
import '../../../core/theme/open_vts_typography.dart';
import '../open_vts_card.dart';

/// Compact metric/KPI card for dashboards.
///
/// Displays icon, title, large value, and optional subtitle.
/// Matches OpenVTS design system and works for both admin and superadmin.
class OpenVtsDashboardMetricCard extends StatelessWidget {
  const OpenVtsDashboardMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = OpenVtsCard(
      padding: const EdgeInsets.fromLTRB(
        OpenVtsSpacing.md,
        OpenVtsSpacing.md,
        OpenVtsSpacing.md,
        OpenVtsSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: OpenVtsTypography.meta.copyWith(
<<<<<<< HEAD
                    color: Theme.of(context).colorScheme.outline,
=======
                    color: OpenVtsColors.textTertiary,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Icon(
                icon,
                size: 16,
<<<<<<< HEAD
                color: Theme.of(context).colorScheme.outline,
=======
                color: OpenVtsColors.textTertiary,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: OpenVtsTypography.numeric.copyWith(
              fontSize: 19,
<<<<<<< HEAD
              color: Theme.of(context).colorScheme.onSurface,
=======
              color: OpenVtsColors.textPrimary,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenVtsTypography.meta.copyWith(
<<<<<<< HEAD
                color: Theme.of(context).colorScheme.onSurfaceVariant,
=======
                color: OpenVtsColors.textSecondary,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return GestureDetector(
      onTap: onTap,
      child: child,
    );
  }
}
