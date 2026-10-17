import 'package:flutter/material.dart';

import '../../core/theme/open_vts_radius.dart';
import '../../core/theme/open_vts_typography.dart';

class OpenVtsStatusChip extends StatelessWidget {
  const OpenVtsStatusChip({
    required this.label,
    required this.type,
    super.key,
  });

  final String label;
  final OpenVtsStatusType type;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = type == OpenVtsStatusType.error
        ? scheme.error
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OpenVtsRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: OpenVtsTypography.meta.copyWith(color: color),
      ),
    );
  }
}

enum OpenVtsStatusType { success, warning, error, info, neutral }
