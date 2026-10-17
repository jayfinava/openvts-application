import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/socket/socket_service.dart';
import 'package:open_vts/core/storage/token_storage.dart';

void main() {
  group('SocketService', () {
    test('telemetry handshake opts out of implicit global scope', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final auth = Completer<Map<String, dynamic>>();
      WebSocket? peer;
      server.listen((request) async {
        peer = await WebSocketTransformer.upgrade(request);
        peer!.add('0${jsonEncode({'sid': 'test-engine', 'upgrades': [], 'pingInterval': 25000, 'pingTimeout': 20000, 'maxPayload': 100000})}');
        peer!.listen((message) {
          if (message is String && message.startsWith('40/telemetry,')) {
            if (!auth.isCompleted) auth.complete(Map<String, dynamic>.from(jsonDecode(message.substring('40/telemetry,'.length)) as Map));
            peer!.add('40/telemetry,{"sid":"test-namespace"}');
          }
        });
      });
      final service = SocketService(TokenStorage(const FlutterSecureStorage()), apiBaseUrl: 'http://127.0.0.1:${server.port}/api');
      try {
        await service.connect('/telemetry');
        final handshake = await auth.future.timeout(const Duration(seconds: 5));
        expect(handshake['telemetryScope'], 'explicit');
      } finally {
        service.dispose();
        await peer?.close();
        await server.close(force: true);
      }
    });

    test('derives namespace URLs from API base without the REST /api path', () {
      expect(
        SocketService.socketUrlForApiBase(
          'https://app.openvts.io/api',
          '/telemetry',
        ),
        'https://app.openvts.io/telemetry',
      );
      expect(
        SocketService.socketUrlForApiBase(
          'https://app.openvts.io/api/',
          'notifications',
        ),
        'https://app.openvts.io/notifications',
      );
      expect(
        SocketService.socketUrlForApiBase('/api', '/telemetry'),
        '/telemetry',
      );
    });
  });
}
