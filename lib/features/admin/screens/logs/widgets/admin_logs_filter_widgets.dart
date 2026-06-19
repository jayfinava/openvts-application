import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_colors.dart';
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
<<<<<<< HEAD
    final backgroundColor = selected
        ? OpenVtsColors.brandInk
        : Theme.of(context).colorScheme.surfaceContainerHigh;
    final foregroundColor = selected
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;
    final borderColor = selected
        ? OpenVtsColors.brandInk
        : Theme.of(context).colorScheme.outline;

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
              fontWeight: FontWeight.w600,
            ),
=======
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? OpenVtsColors.brandInk : OpenVtsColors.white,
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          border: Border.all(
              color: selected ? OpenVtsColors.brandInk : OpenVtsColors.border),
        ),
        child: Text(
          label,
          style: OpenVtsTypography.meta.copyWith(
            color: selected ? OpenVtsColors.white : OpenVtsColors.textSecondary,
            fontWeight: FontWeight.w600,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
          ),
        ),
      ),
    );
  }
}
