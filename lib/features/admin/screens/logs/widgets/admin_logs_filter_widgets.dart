import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_typography.dart';

class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        selected ? colorScheme.primary : colorScheme.surfaceContainerHigh;
    final foregroundColor =
        selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;
    final borderColor = selected ? colorScheme.primary : colorScheme.outline;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OpenVtsRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OpenVtsRadius.md),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Text(
            label,
            style: OpenVtsTypography.meta.copyWith(
              color: foregroundColor,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
