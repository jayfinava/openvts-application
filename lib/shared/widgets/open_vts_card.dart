import 'package:flutter/material.dart';

import '../../core/theme/open_vts_colors.dart';
import '../../core/theme/open_vts_radius.dart';
import '../../core/theme/open_vts_spacing.dart';

class OpenVtsCard extends StatelessWidget {
  const OpenVtsCard({
    required this.child,
    this.padding = const EdgeInsets.all(OpenVtsSpacing.md),
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final isDark = Theme.of(context).brightness == Brightness.dark;
=======
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
<<<<<<< HEAD
        border: Border.all(
          color: isDark ? OpenVtsColors.darkBorder : OpenVtsColors.border,
        ),
=======
        border: Border.all(color: OpenVtsColors.border),
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
      ),
      child: child,
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
      onTap: onTap,
      child: card,
    );
  }
}
