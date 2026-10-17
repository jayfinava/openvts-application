import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/features/auth/services/server_url_configuration.dart';

void main() {
  test('plain URL QR code is normalized for API requests', () {
    expect(
      apiBaseUrlFromQrCode('  https://fleet.example/api/  '),
      'https://fleet.example/api',
    );
  });

  test('JSON QR code may provide apiBaseUrl', () {
    expect(
      apiBaseUrlFromQrCode('{"apiBaseUrl":"https://fleet.example/v1/api"}'),
      'https://fleet.example/v1/api',
    );
  });

  test('unrelated and unsafe QR codes cannot change the server', () {
    for (final value in [
      null,
      '',
      'fleet.example/api',
      'javascript:alert(1)',
      'https://user:secret@fleet.example/api',
      'https://fleet.example/api?token=secret',
      '{"website":"https://fleet.example/api"}',
      '{not json}',
    ]) {
      expect(apiBaseUrlFromQrCode(value), isNull, reason: '$value');
    }
  });
}
