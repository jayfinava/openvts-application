import 'package:flutter/material.dart';
import 'package:open_vts/core/theme/open_vts_radius.dart';
import 'package:open_vts/core/theme/open_vts_spacing.dart';
import 'package:open_vts/core/theme/open_vts_typography.dart';

class OpenVtsSupportFilterChip extends StatelessWidget {
  const OpenVtsSupportFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        selected ? (isDark ? Colors.black : Colors.white) : Colors.transparent;
    final textColor = isDark ? Colors.white : Colors.black;
    final borderColor =
        isDark ? Colors.white : Colors.black.withValues(alpha: 0.2);

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(
          color:
              selected ? (isDark ? Colors.white : Colors.black) : borderColor,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OpenVtsSpacing.sm,
              vertical: OpenVtsSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: OpenVtsTypography.meta.copyWith(
                    color: textColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: OpenVtsSpacing.xxs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OpenVtsSpacing.xxs,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black : Colors.white,
                      border: Border.all(
                        color: borderColor,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(OpenVtsRadius.sm),
                    ),
                    child: Text(
                      count.toString(),
                      style: OpenVtsTypography.meta.copyWith(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
