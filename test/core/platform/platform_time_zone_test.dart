import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/errors/app_error.dart';
import 'package:open_vts/core/platform/platform_time_zone.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('openvts/timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  for (final name in [
    'Asia/Kolkata',
    'Asia/Calcutta',
    'America/New_York',
    'Etc/GMT-5',
    'UTC'
  ]) {
    test('preserves the native named zone $name', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => name);
      expect(await PlatformTimeZone.current(), name);
    });
  }
  test('normalizes the native GMT UTC alias', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => 'GMT');
    expect(await PlatformTimeZone.current(), 'UTC');
  });
  for (final name in [
    '+05:30',
    'GMT+05:30',
    'GMT-0400',
    'India Standard Time',
    'Asia/Calcutta\nprivate'
  ]) {
    test('never sends an unsupported offset or malformed zone: $name',
        () async {
      messenger.setMockMethodCallHandler(channel, (_) async => name);
      await expectLater(PlatformTimeZone.current(), throwsA(isA<AppError>()));
    });
  }
}
