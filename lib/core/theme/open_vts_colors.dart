import 'package:flutter/material.dart';

class OpenVtsColors {
  const OpenVtsColors._();

  static const brandInk = Color(0xFF141414);
  static const brandInkSoft = Color(0xFF1D1D1D);
  static const white = Color(0xFFFFFFFF);

  static const background = Color(0xFFFAFAFA);
  static const surface = Color(0xFFF4F4F4);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E5E5);
  static const divider = Color(0xFFD4D4D4);

  static const textPrimary = Color(0xFF141414);
  static const textSecondary = Color(0xFF666666);
  static const textTertiary = Color(0xFF767676);

  // Status meaning comes from labels/icons, never a hue. This mid-gray remains
  // readable against both black and white for legacy status foregrounds.
  static const success = Color(0xFF767676);
  static const warning = Color(0xFF767676);
  static const error = Color(0xFF767676);
  static const info = Color(0xFF767676);

  static const darkBackground = Color(0xFF000000);
  static const darkSurface = Color(0xFF0B0B0B);
  static const darkSurfaceElevated = Color(0xFF111111);
  static const darkBorder = Color(0x1FFFFFFF);
  static const darkBorderStrong = Color(0x3DFFFFFF);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xB3FFFFFF);
  static const darkTextTertiary = Color(0x99FFFFFF);

  /// Paint-time treatment for app imagery; original media and stored colors
  /// remain intact. Map tiles, vehicle icons and overlays retain original colors.
  static const monochromeFilter = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  /// Normalize externally supplied presentation colors without modifying the
  /// corresponding API model, identifier or saved configuration.
  static Color monochrome(Color value) {
    final argb = value.toARGB32();
    final gray = (((argb >> 16) & 255) * 54 +
            ((argb >> 8) & 255) * 183 +
            (argb & 255) * 19 +
            128) >>
        8;
    return Color((argb & 0xFF000000) | (gray << 16) | (gray << 8) | gray);
  }
}
