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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = selected
        ? OpenVtsColors.brandInk
        : isDark
            ? OpenVtsColors.darkSurface
            : OpenVtsColors.white;
    final borderColor = selected
        ? OpenVtsColors.brandInk
        : isDark
            ? OpenVtsColors.darkBorder
            : OpenVtsColors.border;
    final textColor = selected
        ? OpenVtsColors.white
        : isDark
            ? OpenVtsColors.darkTextSecondary
            : OpenVtsColors.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          label,
          style: OpenVtsTypography.meta.copyWith(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
