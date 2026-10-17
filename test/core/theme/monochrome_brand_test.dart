import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/theme/open_vts_chart_theme.dart';
import 'package:open_vts/core/theme/open_vts_colors.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/features/onboarding/models/onboarding_model.dart';
import 'package:open_vts/features/onboarding/presentation/widgets/onboarding_page.dart';
import 'package:open_vts/features/user/screens/dashboard/widgets/user_dashboard_widget_card.dart';
import 'package:open_vts/features/user/screens/landmarks/widgets/user_landmark_color_picker.dart';
import 'package:open_vts/shared/widgets/open_vts_button.dart';
import 'package:open_vts/shared/widgets/open_vts_map_layer_selector.dart';
import 'package:open_vts/shared/widgets/open_vts_status_chip.dart';

void _expectGray(Color color, {String? reason}) {
  final argb = color.toARGB32();
  expect((argb >> 16) & 255, (argb >> 8) & 255, reason: reason);
  expect((argb >> 8) & 255, argb & 255, reason: reason);
}

double _contrast(Color foreground, Color background) {
  final fg = Color.alphaBlend(foreground, background).computeLuminance();
  final bg = background.computeLuminance();
  return ((fg > bg ? fg : bg) + .05) / ((fg > bg ? bg : fg) + .05);
}

Future<void> _captureGray(WidgetTester tester, GlobalKey key, String? file,
    {List<Rect> naturalImagery = const []}) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final bytes = data.buffer.asUint8List();
    var colored = 0;
    var naturalColored = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i + 3] == 0) continue;
      if ((bytes[i] - bytes[i + 1]).abs() > 1 ||
          (bytes[i + 1] - bytes[i + 2]).abs() > 1) {
        final pixel = i ~/ 4;
        final position =
            Offset((pixel % image.width) + .5, (pixel ~/ image.width) + .5);
        if (naturalImagery.any((bounds) => bounds.contains(position))) {
          naturalColored++;
        } else {
          colored++;
        }
      }
    }
    if (naturalImagery.isNotEmpty) {
      expect(naturalColored, greaterThan(0),
          reason: 'Map previews must retain their natural imagery colors.');
    }
    if (file != null) {
      final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File(file).writeAsBytesSync(png.buffer.asUint8List());
    }
    image.dispose();
    expect(colored, 0, reason: 'Rendered pixels must be black, white or gray.');
  });
}

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final bytes = font.readAsBytesSync();
      for (final family in ['Inter', 'Satoshi']) {
        await (FontLoader(family)
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      }
    }
    final icons = File(
        'C:/src/flutter_windows_3.41.9-stable/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')
            ..addFont(
                Future.value(ByteData.sublistView(icons.readAsBytesSync()))))
          .load();
    }
  });
  test('non-map app colors cannot reintroduce colored accents', () {
    final failures = <String>[];
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      final path = file.path.replaceAll('\\', '/');
      // Maps, their controls and landmark configuration retain original colors.
      if (path.startsWith('lib/features/live_map/screens/') ||
          path.startsWith('lib/features/user/screens/landmarks/') ||
          path.contains('/screens/map/') ||
          path.startsWith('lib/shared/widgets/open_vts_map_') ||
          path.startsWith(
              'lib/features/user/screens/operations/user_operation_route_') ||
          path == 'lib/features/driver/screens/driver_route_map.dart' ||
          path == 'lib/core/theme/open_vts_map_colors.dart') {
        continue;
      }
      for (final match
          in RegExp(r'\bColor\(\s*0x([0-9a-fA-F]{8})').allMatches(source)) {
        final color = int.parse(match[1]!, radix: 16);
        if (((color >> 16) & 255) != ((color >> 8) & 255) ||
            ((color >> 8) & 255) != (color & 255)) {
          failures.add('${file.path}: ${match[0]}');
        }
      }
      if (RegExp(
              r'\bColors\.(red|blue|green|yellow|orange|purple|pink|cyan|teal|indigo|amber|lime|brown|deepOrange|deepPurple|lightBlue|lightGreen|blueGrey)\b')
          .hasMatch(source)) {
        failures.add('${file.path}: colored Material palette');
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('external colors become neutral without changing transparency or data',
      () {
    for (final value in [0xFFE84A21, 0xFF1A8DE2, 0x8000CD55, 0x00FFFFFF]) {
      final input = Color(value);
      final result = OpenVtsColors.monochrome(input);
      _expectGray(result);
      expect(result.toARGB32() >> 24, input.toARGB32() >> 24);
      expect(input.toARGB32(), value);
    }
  });

  for (final brightness in Brightness.values) {
    final name = brightness.name;
    final theme =
        brightness == Brightness.dark ? OpenVtsTheme.dark : OpenVtsTheme.light;

    test('$name theme has neutral roles and readable foregrounds', () {
      final scheme = theme.colorScheme;
      final diagnostics = DiagnosticPropertiesBuilder();
      scheme.debugFillProperties(diagnostics);
      for (final property
          in diagnostics.properties.whereType<ColorProperty>()) {
        if (property.value != null) {
          _expectGray(property.value!, reason: property.name);
        }
      }
      for (final color in [
        theme.primaryColor,
        theme.primaryColorLight,
        theme.primaryColorDark,
        theme.scaffoldBackgroundColor,
        theme.textSelectionTheme.cursorColor!,
        theme.textSelectionTheme.selectionColor!,
        theme.textSelectionTheme.selectionHandleColor!,
        theme.cupertinoOverrideTheme!.primaryColor!
      ]) {
        _expectGray(color);
      }
      for (final (fg, bg) in [
        (scheme.onPrimary, scheme.primary),
        (scheme.onPrimaryContainer, scheme.primaryContainer),
        (scheme.onSecondaryContainer, scheme.secondaryContainer),
        (scheme.onTertiaryContainer, scheme.tertiaryContainer),
        (scheme.onSurface, scheme.surface),
        (scheme.onSurfaceVariant, scheme.surface),
        (scheme.error, scheme.surface),
        (scheme.onErrorContainer, scheme.errorContainer),
        (scheme.onInverseSurface, scheme.inverseSurface),
      ]) {
        expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets(
        '$name real controls, status labels and error state render neutral',
        (tester) async {
      tester.view.physicalSize = const Size(430, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      var retry = 0;
      final request = RequestOptions();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
                body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('OpenVTS',
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final type in OpenVtsStatusType.values)
                        OpenVtsStatusChip(label: type.name, type: type),
                    ]),
                    const SizedBox(height: 16),
                    const TextField(
                        decoration: InputDecoration(
                            labelText: 'Vehicle search',
                            errorText: 'Choose a vehicle')),
                    const SizedBox(height: 16),
                    OpenVtsButton(label: 'Generate Report', onPressed: () {}),
                    const SizedBox(height: 16),
                    UserDashboardWidgetError(
                      error: DioException.badResponse(
                          statusCode: 503,
                          requestOptions: request,
                          response: Response(
                              requestOptions: request, statusCode: 503)),
                      onRetry: () => retry++,
                    ),
                  ]),
            ))),
      ));
      await tester.pumpAndSettle();
      for (final type in OpenVtsStatusType.values) {
        expect(find.text(type.name), findsOneWidget);
      }
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(retry, 1);
      await _captureGray(tester, key, 'build/brand-$name.png');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        '$name map selector keeps original previews and selection colors',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: Scaffold(
                body: OpenVtsMapLayerSelectorButton(
              selectedLayerId: primaryMapLayerOptions.first.id,
              onLayerSelected: (_) {},
            )),
          )));
      await tester.tap(find.byType(OpenVtsMapLayerSelectorButton));
      await tester.pumpAndSettle();
      expect(find.text('Map type'), findsOneWidget);
      final previews = find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_MapLayerPreview');
      expect(previews, findsWidgets);
      expect(tester.widget<Text>(find.text('Road')).style!.color,
          const Color(0xFF1293A6));
      await _captureGray(tester, key, 'build/brand-map-$name.png',
          naturalImagery: [tester.getRect(find.byKey(key))]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name chart series and tooltips are distinct and readable',
        (tester) async {
      late BuildContext context;
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Builder(builder: (value) {
            context = value;
            return const SizedBox();
          })));
      final tones = [
        for (var i = 0; i < 4; i++) OpenVtsChartTheme.series(context, i)
      ];
      expect(tones.toSet().length, 4);
      for (final color in tones) {
        _expectGray(color);
        expect(_contrast(OpenVtsChartTheme.labelOn(color), color),
            greaterThanOrEqualTo(4.5));
      }
      final tooltip = OpenVtsChartTheme.barTouchData(context).touchTooltipData;
      final rod = BarChartRodData(toY: 12, color: tones.first);
      final group = BarChartGroupData(x: 0, barRods: [rod]);
      final fill = tooltip.getTooltipColor(group);
      final item = tooltip.getTooltipItem(group, 0, rod, 0)!;
      _expectGray(fill);
      expect(item.text, '12.0');
      expect(_contrast(item.textStyle.color!, fill), greaterThanOrEqualTo(4.5));
      final line =
          LineChartBarData(spots: [const FlSpot(0, 12)], color: tones.first);
      final spot = LineBarSpot(line, 0, line.spots.single);
      final lineTooltip =
          OpenVtsChartTheme.lineTouchData(context).touchTooltipData;
      final lineFill = lineTooltip.getTooltipColor(spot);
      final lineItem = lineTooltip.getTooltipItems([spot]).single!;
      _expectGray(lineFill);
      expect(_contrast(lineItem.textStyle.color!, lineFill),
          greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('existing colored onboarding asset renders in grayscale',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
        theme: OpenVtsTheme.light,
        home: RepaintBoundary(
          key: key,
          child: Scaffold(
              body: OnboardingPage(
                  page: OnboardingModel(
            image: 'assets/images/vehicleicons/carGreen.png',
            title: 'Fleet tracking',
            subtitle: 'Vehicle status',
          ))),
        )));
    await tester.pumpAndSettle();
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image)).image, isA<AssetImage>());
    await _captureGray(tester, key, null);
  });

  testWidgets('landmark palette and custom values keep their original colors',
      (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
        theme: OpenVtsTheme.light,
        home: Scaffold(
          body: UserLandmarkColorPicker(
              value: '#141414', onChanged: (value) => selected = value),
        )));
    await tester.enterText(find.byType(TextField), '#FF0000');
    expect(selected, '#FF0000');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(selected, '#FF0000');
    expect(kUserLandmarkPalette,
        containsAll(['#1F6FEB', '#10B981', '#EF4444', '#F59E0B']));
  });
}
