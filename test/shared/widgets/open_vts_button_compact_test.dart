import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/shared/widgets/open_vts_button.dart';

void main() {
  for (final theme in [OpenVtsTheme.light, OpenVtsTheme.dark]) {
    for (final height in [32.0, 34.0]) {
      testWidgets('compact $height px action keeps its label visible',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                height: height,
                child: OpenVtsButton(
                  label: 'Assign Vehicle',
                  height: height,
                  trailingIcon: Icons.add_rounded,
                  onPressed: () {},
                ),
              ),
            ),
          ),
        ));

        expect(find.text('Assign Vehicle'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
