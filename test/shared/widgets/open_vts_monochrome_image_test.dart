import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/shared/widgets/open_vts_monochrome_image.dart';

void main() {
  for (final asset in [
    'assets/brand/icon.png',
    'assets/images/vehicleicons/carGreen.png',
  ]) {
    testWidgets('$asset retains transparent pixels in neutral UI',
        (tester) async {
      final key = GlobalKey();
      final provider = AssetImage(asset);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 64,
              height: 64,
              child: OpenVtsMonochromeImage(child: Image(image: provider)),
            ),
          ),
        ),
      ));
      await tester.runAsync(() => precacheImage(
            provider,
            tester.element(find.byType(Image)),
          ));
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        try {
          final data =
              (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final pixels = data.buffer.asUint8List();
          expect(pixels[3], 0,
              reason: 'The PNG corner must not gain an opaque background.');
          var visiblePixels = 0;
          for (var i = 0; i < pixels.length; i += 4) {
            if (pixels[i + 3] == 0) continue;
            visiblePixels++;
            expect((pixels[i] - pixels[i + 1]).abs(), lessThanOrEqualTo(1));
            expect((pixels[i + 1] - pixels[i + 2]).abs(), lessThanOrEqualTo(1));
          }
          expect(visiblePixels, greaterThan(0));
        } finally {
          image.dispose();
        }
      });
    });
  }
}
