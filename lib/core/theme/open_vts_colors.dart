import 'package:flutter/material.dart';

class OpenVtsColors {
  const OpenVtsColors._();

  static const brandInk = Color(0xFF141118);
  static const brandInkSoft = Color(0xFF1D1821);
  static const white = Color(0xFFFFFFFF);

  static const background = Color(0xFFFAFAFB);
  static const surface = Color(0xFFF4F3F6);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7E3EA);
  static const divider = Color(0xFFD8D3DC);

  static const textPrimary = Color(0xFF141118);
  static const textSecondary = Color(0xFF6B6570);
  static const textTertiary = Color(0xFF908A96);

  static const success = Color(0xFF2F6B4F);
  static const warning = Color(0xFF8A6522);
  static const error = Color(0xFF8A3333);
  static const info = Color(0xFF435A6B);

  static const darkBackground = Color(0xFF0F0D12);
  static const darkSurface = Color(0xFF18141D);
  static const darkSurfaceElevated = Color(0xFF211D26);
  static const darkBorder = Color(0xFF2A2430);
  static const darkTextPrimary = Color(0xFFFFFFFF);
  static const darkTextSecondary = Color(0xFFC8C2CD);
  static const darkTextTertiary = Color(0xFF9E98A4);

  static const darkSuccess = Color(0xFF4A9E6E);
  static const darkWarning = Color(0xFFC9A33A);
  static const darkError = Color(0xFFC24D4D);
  static const darkInfo = Color(0xFF5A7FA4);
}

extension ThemeAwareColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color textPrimary() => isDarkMode ? OpenVtsColors.darkTextPrimary : OpenVtsColors.textPrimary;
  Color textSecondary() => isDarkMode ? OpenVtsColors.darkTextSecondary : OpenVtsColors.textSecondary;
  Color textTertiary() => isDarkMode ? OpenVtsColors.darkTextTertiary : OpenVtsColors.textTertiary;
  Color surface() => isDarkMode ? OpenVtsColors.darkSurface : OpenVtsColors.surface;
  Color border() => isDarkMode ? OpenVtsColors.darkBorder : OpenVtsColors.border;
  Color error() => isDarkMode ? OpenVtsColors.darkError : OpenVtsColors.error;
  Color success() => isDarkMode ? OpenVtsColors.darkSuccess : OpenVtsColors.success;
  Color warning() => isDarkMode ? OpenVtsColors.darkWarning : OpenVtsColors.warning;
  Color info() => isDarkMode ? OpenVtsColors.darkInfo : OpenVtsColors.info;
}
