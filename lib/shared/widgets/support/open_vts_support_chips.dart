import 'package:flutter/material.dart';
import 'package:open_vts/core/theme/open_vts_colors.dart';
import 'package:open_vts/core/theme/open_vts_radius.dart';
import 'package:open_vts/core/theme/open_vts_spacing.dart';
import 'package:open_vts/core/theme/open_vts_typography.dart';

class OpenVtsSupportSoftChip extends StatelessWidget {
  const OpenVtsSupportSoftChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OpenVtsSpacing.xs,
        vertical: OpenVtsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      ),
      child: Text(
        label,
        style: OpenVtsTypography.meta.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class OpenVtsSupportPlainChip extends StatelessWidget {
  const OpenVtsSupportPlainChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final isDark = Theme.of(context).brightness == Brightness.dark;
=======
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OpenVtsSpacing.xs,
        vertical: OpenVtsSpacing.xxs,
      ),
      decoration: BoxDecoration(
<<<<<<< HEAD
        border: Border.all(
          color: isDark ? OpenVtsColors.darkBorder : OpenVtsColors.border,
        ),
=======
        border: Border.all(color: OpenVtsColors.border),
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: OpenVtsTypography.meta.copyWith(
<<<<<<< HEAD
          color: isDark
              ? OpenVtsColors.darkTextSecondary
              : OpenVtsColors.textSecondary,
=======
          color: OpenVtsColors.textSecondary,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
