import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'open_vts_colors.dart';
import 'open_vts_radius.dart';
import 'open_vts_typography.dart';

class OpenVtsTheme {
  const OpenVtsTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final foreground =
        isDark ? OpenVtsColors.darkTextPrimary : OpenVtsColors.textPrimary;
    final background =
        isDark ? OpenVtsColors.darkBackground : OpenVtsColors.background;
    final border = isDark ? OpenVtsColors.darkBorder : OpenVtsColors.border;
    final scheme = isDark
        ? const ColorScheme.dark(
            primary: OpenVtsColors.white,
            onPrimary: OpenVtsColors.brandInk,
            secondary: OpenVtsColors.darkTextSecondary,
            onSecondary: OpenVtsColors.darkBackground,
            primaryContainer: Color(0xFF262626),
            onPrimaryContainer: Colors.white,
            secondaryContainer: Color(0xFF262626),
            onSecondaryContainer: Colors.white,
            tertiary: Color(0xFFD4D4D4),
            onTertiary: Colors.black,
            tertiaryContainer: Color(0xFF262626),
            onTertiaryContainer: Colors.white,
            surface: OpenVtsColors.darkSurface,
            onSurface: OpenVtsColors.darkTextPrimary,
            onSurfaceVariant: OpenVtsColors.darkTextSecondary,
            outline: OpenVtsColors.darkTextSecondary,
            outlineVariant: OpenVtsColors.darkBorder,
            error: Color(0xFFD4D4D4),
            onError: Colors.black,
            errorContainer: Color(0xFF262626),
            onErrorContainer: Color(0xFFF4F4F4),
            surfaceDim: Colors.black,
            surfaceBright: Color(0xFF262626),
            surfaceContainerLowest: Colors.black,
            surfaceContainerLow: Color(0xFF0B0B0B),
            surfaceContainer: Color(0xFF111111),
            surfaceContainerHigh: Color(0xFF1D1D1D),
            surfaceContainerHighest: Color(0xFF262626),
            inverseSurface: Color(0xFFE5E5E5),
            onInverseSurface: Color(0xFF141414),
            inversePrimary: Color(0xFF141414),
            primaryFixed: Color(0xFFE5E5E5),
            primaryFixedDim: Color(0xFFB3B3B3),
            onPrimaryFixed: Colors.black,
            onPrimaryFixedVariant: Color(0xFF262626),
            secondaryFixed: Color(0xFFE5E5E5),
            secondaryFixedDim: Color(0xFFB3B3B3),
            onSecondaryFixed: Colors.black,
            onSecondaryFixedVariant: Color(0xFF262626),
            tertiaryFixed: Color(0xFFE5E5E5),
            tertiaryFixedDim: Color(0xFFB3B3B3),
            onTertiaryFixed: Colors.black,
            onTertiaryFixedVariant: Color(0xFF262626),
            shadow: Colors.black,
            scrim: Colors.black,
            surfaceTint: Colors.transparent,
          )
        : const ColorScheme.light(
            primary: OpenVtsColors.brandInk,
            onPrimary: OpenVtsColors.white,
            secondary: OpenVtsColors.brandInkSoft,
            onSecondary: Colors.white,
            primaryContainer: Color(0xFFE5E5E5),
            onPrimaryContainer: Color(0xFF141414),
            secondaryContainer: Color(0xFFE5E5E5),
            onSecondaryContainer: Color(0xFF141414),
            tertiary: Color(0xFF525252),
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFF4F4F4),
            onTertiaryContainer: Color(0xFF141414),
            surface: OpenVtsColors.surfaceElevated,
            onSurface: OpenVtsColors.textPrimary,
            onSurfaceVariant: OpenVtsColors.textSecondary,
            outline: OpenVtsColors.textSecondary,
            outlineVariant: OpenVtsColors.border,
            error: Color(0xFF525252),
            onError: Colors.white,
            errorContainer: Color(0xFFE5E5E5),
            onErrorContainer: Color(0xFF141414),
            surfaceDim: Color(0xFFE5E5E5),
            surfaceBright: Colors.white,
            surfaceContainerLowest: Colors.white,
            surfaceContainerLow: Color(0xFFFAFAFA),
            surfaceContainer: Color(0xFFF4F4F4),
            surfaceContainerHigh: Color(0xFFEEEEEE),
            surfaceContainerHighest: Color(0xFFE5E5E5),
            inverseSurface: Color(0xFF262626),
            onInverseSurface: Colors.white,
            inversePrimary: Colors.white,
            primaryFixed: Color(0xFFE5E5E5),
            primaryFixedDim: Color(0xFFB3B3B3),
            onPrimaryFixed: Colors.black,
            onPrimaryFixedVariant: Color(0xFF262626),
            secondaryFixed: Color(0xFFE5E5E5),
            secondaryFixedDim: Color(0xFFB3B3B3),
            onSecondaryFixed: Colors.black,
            onSecondaryFixedVariant: Color(0xFF262626),
            tertiaryFixed: Color(0xFFE5E5E5),
            tertiaryFixedDim: Color(0xFFB3B3B3),
            onTertiaryFixed: Colors.black,
            onTertiaryFixedVariant: Color(0xFF262626),
            shadow: Colors.black,
            scrim: Colors.black,
            surfaceTint: Colors.transparent,
          );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      primaryColorLight: scheme.primaryContainer,
      primaryColorDark: scheme.inverseSurface,
      secondaryHeaderColor: scheme.secondaryContainer,
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: scheme.primary,
        primaryContrastingColor: scheme.onPrimary,
        scaffoldBackgroundColor: background,
        barBackgroundColor: scheme.surface,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.onSurface.withValues(alpha: .2),
        selectionHandleColor: scheme.primary,
      ),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OpenVtsRadius.button),
    );
    final sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(OpenVtsRadius.xl),
    );
    final textTheme = base.textTheme.apply(
      fontFamily: OpenVtsTypography.primaryFontFamily,
      fontFamilyFallback: OpenVtsTypography.fontFallback,
      bodyColor: foreground,
      displayColor: foreground,
    );
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(buttonShape),
      textStyle: const WidgetStatePropertyAll(OpenVtsTypography.label),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
    );
    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: OpenVtsTypography.titleSmall.copyWith(
          color: foreground,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder(border),
        enabledBorder: inputBorder(border),
        disabledBorder: inputBorder(border),
        focusedBorder: inputBorder(scheme.primary, 1.5),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.5),
        errorMaxLines: 4,
        helperMaxLines: 4,
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: buttonStyle.copyWith(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.12)
                : scheme.primary,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? scheme.onSurface.withValues(alpha: 0.65)
                : scheme.onPrimary,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: border)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.onPrimary
                  : scheme.onSurface),
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.surface),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          textStyle: const WidgetStatePropertyAll(OpenVtsTypography.label),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: sheetShape,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        constraints: const BoxConstraints(maxWidth: 640),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OpenVtsRadius.xl),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(OpenVtsRadius.md),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
    );
  }
}
