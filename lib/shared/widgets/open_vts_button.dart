import 'package:flutter/material.dart';

import '../../core/theme/open_vts_colors.dart';
import '../../core/theme/open_vts_radius.dart';
import '../../core/theme/open_vts_typography.dart';

class OpenVtsButton extends StatelessWidget {
  const OpenVtsButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = OpenVtsButtonVariant.primary,
    this.trailingIcon,
    this.height = 46,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final OpenVtsButtonVariant variant;
  final IconData? trailingIcon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isPrimary = variant == OpenVtsButtonVariant.primary;
<<<<<<< HEAD
    final isDark = Theme.of(context).brightness == Brightness.dark;
=======
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e

    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              isPrimary ? OpenVtsColors.brandInk : OpenVtsColors.white,
          foregroundColor:
              isPrimary ? OpenVtsColors.white : OpenVtsColors.brandInk,
<<<<<<< HEAD
          disabledBackgroundColor:
              isDark ? OpenVtsColors.darkSurface : OpenVtsColors.surface,
          disabledForegroundColor: isDark
              ? OpenVtsColors.darkTextSecondary
              : OpenVtsColors.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OpenVtsRadius.button),
            side: BorderSide(
              color: isPrimary
                  ? OpenVtsColors.brandInk
                  : (isDark ? OpenVtsColors.darkBorder : OpenVtsColors.border),
=======
          disabledBackgroundColor: OpenVtsColors.surface,
          disabledForegroundColor: OpenVtsColors.textTertiary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OpenVtsRadius.button),
            side: BorderSide(
              color: isPrimary ? OpenVtsColors.brandInk : OpenVtsColors.border,
>>>>>>> 9a00c1c3ad83d590af1eb72db6db5e5a5d47992e
            ),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : trailingIcon == null
                ? Text(label, style: OpenVtsTypography.label)
                : LayoutBuilder(
                    builder: (context, constraints) {
                      if (!constraints.hasBoundedWidth) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: OpenVtsTypography.label,
                            ),
                            const SizedBox(width: 8),
                            Icon(trailingIcon, size: 18),
                          ],
                        );
                      }

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(
                                end: 24,
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: OpenVtsTypography.label,
                              ),
                            ),
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Icon(trailingIcon, size: 18),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }
}

enum OpenVtsButtonVariant { primary, secondary }
