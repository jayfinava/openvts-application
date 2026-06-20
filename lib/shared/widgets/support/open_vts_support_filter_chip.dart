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
    final colorScheme = Theme.of(context).colorScheme;

    final selectedBg = colorScheme.primary;
    final unselectedBg = colorScheme.surfaceContainerHigh;
    final borderColor = selected ? colorScheme.primary : colorScheme.outline;
    final labelColor = selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant;

    return ChoiceChip(
      label: Text('$label $count'),
      selected: selected,
      onSelected: (_) => onSelected(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelPadding: const EdgeInsets.symmetric(horizontal: OpenVtsSpacing.xs),
      selectedColor: selectedBg,
      backgroundColor: unselectedBg,
      side: BorderSide(color: borderColor, width: 1),
      checkmarkColor: colorScheme.onPrimary,
      labelStyle: OpenVtsTypography.meta.copyWith(
        color: labelColor,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      ),
    );
  }
}
