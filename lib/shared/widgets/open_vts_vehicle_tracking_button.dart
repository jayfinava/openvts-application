import 'package:flutter/material.dart';

import '../../core/theme/open_vts_colors.dart';
import '../../core/theme/open_vts_radius.dart';
import '../helpers/mobile_text.dart';

/// A consistent, high-contrast tracking action for vehicle list cards.
class OpenVtsVehicleTrackingButton extends StatelessWidget {
  const OpenVtsVehicleTrackingButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final label = context.mobileText('Track vehicle');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? OpenVtsColors.darkSurface
        : OpenVtsColors.background;
    final borderColor = isDark
        ? OpenVtsColors.darkBorder
        : OpenVtsColors.border;
    final foregroundColor = isDark
        ? OpenVtsColors.darkTextPrimary
        : OpenVtsColors.brandInk;

    return Tooltip(
      message: label,
      child: SizedBox.square(
        dimension: 48,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(OpenVtsRadius.lg),
            splashColor: foregroundColor.withValues(alpha: 0.08),
            highlightColor: foregroundColor.withValues(alpha: 0.04),
            child: Center(
              child: Ink(
                key: const ValueKey('vehicle-tracking-button'),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  Icons.gps_fixed_rounded,
                  size: 20,
                  color: foregroundColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
