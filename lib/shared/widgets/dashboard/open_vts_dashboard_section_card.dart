import 'package:flutter/material.dart';

import '../../../core/theme/open_vts_radius.dart';
import '../../../core/theme/open_vts_spacing.dart';
import '../../../core/theme/open_vts_typography.dart';
import '../open_vts_card.dart';

/// Section card with optional header icon, title, and content.
///
/// Used for dashboard sections like "Vehicle Live Status", "Revenue Forecast", etc.
/// Compact header with divider, supports custom child content.
class OpenVtsDashboardSectionCard extends StatelessWidget {
  const OpenVtsDashboardSectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.headerBackgroundColor,
    super.key,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  final Color? headerBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return OpenVtsCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OpenVtsSpacing.md,
              vertical: OpenVtsSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: headerBackgroundColor ?? Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(OpenVtsRadius.sm),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: OpenVtsSpacing.xs),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OpenVtsTypography.titleSmall.copyWith(
                      fontSize: 18,
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: OpenVtsSpacing.xs),
                  trailing!,
                ],
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
          child,
        ],
      ),
    );
  }
}
