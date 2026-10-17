import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/features/user/messages/user_message_models.dart';
import 'package:open_vts/features/user/messages/user_messages_screen.dart';

void main() {
  for (final theme in [OpenVtsTheme.light, OpenVtsTheme.dark]) {
    testWidgets('outgoing message uses the primary surface text color',
        (tester) async {
      const message = UserChatMessage(
        id: '1',
        driverId: 1,
        senderType: 'USER',
        senderName: 'You',
        body: 'Message driver',
        isRead: false,
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: const Scaffold(
          body: UserMessageBubble(message: message, timestamp: '10:00'),
        ),
      ));

      final bubble = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(bubble.style?.color, theme.colorScheme.onPrimary);
      expect(tester.widget<Card>(find.byType(Card)).color,
          theme.colorScheme.primary);
    });
  }
}
