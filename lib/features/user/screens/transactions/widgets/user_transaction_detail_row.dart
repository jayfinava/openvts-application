import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';

class UserTransactionDetailRow extends StatelessWidget {
  const UserTransactionDetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
    this.onCopy,
    this.copyTooltip = 'Copy value',
    super.key,
  });

  final String label;
  final String value;
  final bool multiline;
  final VoidCallback? onCopy;
  final String copyTooltip;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment:
          multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 108,
          child: Text(
            label,
            style: OpenVtsTypography.meta.copyWith(
              color: isDark
                  ? OpenVtsColors.darkTextTertiary
                  : OpenVtsColors.textTertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: OpenVtsSpacing.xs),
        Expanded(
          child: Text(
            value,
            maxLines: multiline ? null : 2,
            overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
            style: OpenVtsTypography.body.copyWith(
              color: isDark
                  ? OpenVtsColors.darkTextPrimary
                  : OpenVtsColors.textPrimary,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: OpenVtsSpacing.xxs),
          IconButton(
            tooltip: copyTooltip,
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            onPressed: onCopy,
            icon: const Icon(Icons.content_copy_rounded, size: 16),
            color: isDark
                ? OpenVtsColors.darkTextSecondary
                : OpenVtsColors.textSecondary,
          ),
        ],
      ],
    );
  }
}
