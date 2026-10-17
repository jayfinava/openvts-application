import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Explicit chart styles prevent third-party tooltip defaults from introducing
/// colored surfaces. Series remain distinguishable through tones and labels.
class OpenVtsChartTheme {
  const OpenVtsChartTheme._();

  static Color series(BuildContext context, int index) {
    final tones = Theme.of(context).brightness == Brightness.dark
        ? const [
            Color(0xFFF4F4F4),
            Color(0xFFB3B3B3),
            Color(0xFF767676),
            Color(0xFF606060)
          ]
        : const [
            Color(0xFF262626),
            Color(0xFF666666),
            Color(0xFFA3A3A3),
            Color(0xFFD4D4D4)
          ];
    return tones[index % tones.length];
  }

  static Color labelOn(Color background) =>
      background.computeLuminance() > .179 ? Colors.black : Colors.white;

  static BarTouchData barTouchData(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BarTouchData(
        touchTooltipData: BarTouchTooltipData(
      getTooltipColor: (_) => scheme.inverseSurface,
      getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
        rod.toY.toString(),
        TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600),
      ),
    ));
  }

  static LineTouchData lineTouchData(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LineTouchData(
        touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => scheme.inverseSurface,
      getTooltipItems: (spots) => spots
          .map((spot) => LineTooltipItem(
                spot.y.toString(),
                TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w600),
              ))
          .toList(growable: false),
    ));
  }
}
