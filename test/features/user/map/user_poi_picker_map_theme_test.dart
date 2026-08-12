import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_vts/core/theme/open_vts_colors.dart';
import 'package:open_vts/features/user/screens/landmarks/pois/widgets/user_poi_picker_map.dart';

class _DeferredSearchAdapter implements HttpClientAdapter {
  final response = Completer<ResponseBody>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return response.future;
  }

  void completeWithResult() {
    response.complete(
      ResponseBody.fromString(
        jsonEncode([
          {
            'lat': '28.6139',
            'lon': '77.2090',
            'display_name': 'New Delhi, Delhi, India',
          },
        ]),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required ThemeMode themeMode,
  required Dio searchClient,
  LatLng? initialPoint,
  double? initialTolerance,
}) async {
  tester.view.physicalSize = const Size(900, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(searchClient.close);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      home: UserPoiPickerMap(
        initialPoint: initialPoint,
        initialToleranceM: initialTolerance,
        searchClient: searchClient,
      ),
    ),
  );
  await tester.pump();
}

TextField _fieldWithLabel(WidgetTester tester, String label) {
  return tester.widget<TextField>(
    find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == label,
    ),
  );
}

void main() {
  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    final themeName = themeMode.name;

    testWidgets('$themeName empty controls and disabled save stay readable', (
      tester,
    ) async {
      final dio = Dio()..httpClientAdapter = _DeferredSearchAdapter();
      await _pumpPicker(
        tester,
        themeMode: themeMode,
        searchClient: dio,
      );

      final search = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Search place...'),
      );
      expect(search.style?.color, OpenVtsColors.white);
      expect(_fieldWithLabel(tester, 'Latitude').style?.color,
          OpenVtsColors.white);
      expect(_fieldWithLabel(tester, 'Longitude').style?.color,
          OpenVtsColors.white);
      expect(find.text('Tap map to place POI'), findsOneWidget);
      expect(find.text('Tolerance'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$themeName loading, results and selected values are readable',
        (
      tester,
    ) async {
      final adapter = _DeferredSearchAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      await _pumpPicker(
        tester,
        themeMode: themeMode,
        searchClient: dio,
        initialPoint: const LatLng(12.100001, 77.050001),
        initialTolerance: 75,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Search place...'),
        'New Delhi',
      );
      await tester.pump();

      final spinner = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(
        spinner.valueColor?.value,
        OpenVtsColors.white.withValues(alpha: 0.85),
      );

      await tester.runAsync(() async {
        adapter.completeWithResult();
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final result = tester.widget<Text>(find.text('New Delhi, Delhi, India'));
      expect(result.style?.color, OpenVtsColors.white);
      await tester.tap(find.text('New Delhi, Delhi, India'));
      await tester.pump();

      expect(_fieldWithLabel(tester, 'Latitude').controller?.text, '28.613900');
      expect(
        _fieldWithLabel(tester, 'Longitude').controller?.text,
        '77.209000',
      );
      expect(find.text('75'), findsOneWidget);
      expect(find.text('Use this location'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
