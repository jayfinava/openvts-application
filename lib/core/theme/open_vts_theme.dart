import 'package:flutter/material.dart';

import 'open_vts_colors.dart';
import 'open_vts_radius.dart';
import 'open_vts_typography.dart';

class OpenVtsTheme {
  const OpenVtsTheme._();

  static TextTheme _interTextTheme(ThemeData base, Color textColor) {
    return base.textTheme.apply(
      fontFamily: OpenVtsTypography.primaryFontFamily,
      fontFamilyFallback: OpenVtsTypography.fontFallback,
      bodyColor: textColor,
      displayColor: textColor,
    );
  }

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = _interTextTheme(base, OpenVtsColors.textPrimary);

    return base.copyWith(
      scaffoldBackgroundColor: OpenVtsColors.background,
      colorScheme: const ColorScheme.light(
        primary: OpenVtsColors.brandInk,
        secondary: OpenVtsColors.brandInkSoft,
        surface: OpenVtsColors.surfaceElevated,
        error: OpenVtsColors.error,
        onSurface: OpenVtsColors.textPrimary,
        onSurfaceVariant: OpenVtsColors.textSecondary,
        outlineVariant: OpenVtsColors.border,
        surfaceContainer: OpenVtsColors.surface,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: OpenVtsColors.background,
        foregroundColor: OpenVtsColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: OpenVtsTypography.titleSmall.copyWith(
          color: OpenVtsColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OpenVtsColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: const BorderSide(color: OpenVtsColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: const BorderSide(color: OpenVtsColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: const BorderSide(color: OpenVtsColors.brandInk),
        ),
        hintStyle: const TextStyle(color: OpenVtsColors.textSecondary),
        labelStyle: const TextStyle(color: OpenVtsColors.textSecondary),
        errorStyle: const TextStyle(color: OpenVtsColors.error),
        helperStyle: const TextStyle(color: OpenVtsColors.textTertiary),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = _interTextTheme(base, OpenVtsColors.darkTextPrimary);

    return base.copyWith(
      scaffoldBackgroundColor: OpenVtsColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: OpenVtsColors.white,
        secondary: OpenVtsColors.darkTextSecondary,
        surface: OpenVtsColors.darkSurface,
        error: OpenVtsColors.error,
        onSurface: OpenVtsColors.darkTextPrimary,
        onSurfaceVariant: OpenVtsColors.darkTextSecondary,
        outlineVariant: OpenVtsColors.darkBorder,
        surfaceContainer: Color(0xFF201C28),
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: OpenVtsColors.darkBackground,
        foregroundColor: OpenVtsColors.darkTextPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: OpenVtsTypography.titleSmall.copyWith(
          color: OpenVtsColors.darkTextPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: OpenVtsColors.darkSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: const BorderSide(color: OpenVtsColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: const BorderSide(color: OpenVtsColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: const BorderSide(color: OpenVtsColors.white),
        ),
        hintStyle: const TextStyle(color: OpenVtsColors.darkTextSecondary),
        labelStyle: const TextStyle(color: OpenVtsColors.darkTextSecondary),
        errorStyle: const TextStyle(color: OpenVtsColors.darkError),
        helperStyle: const TextStyle(color: OpenVtsColors.darkTextSecondary),
      ),
    );
  }
}
