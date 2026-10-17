import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../errors/app_error.dart';
import 'browser_time_zone_stub.dart'
    if (dart.library.js_interop) 'browser_time_zone_web.dart';

/// Resolves a backend-valid report timezone.
///
/// Native platforms and the browser must agree with their local date boundaries.
/// The report database requires named zones; an offset loses DST/history rules.
class PlatformTimeZone {
  const PlatformTimeZone._();

  static const MethodChannel _channel = MethodChannel('openvts/timezone');

  static Future<String> current() async {
    if (kIsWeb) {
      final namedZone = _normalizeNativeIdentifier(browserTimeZone());
      if (namedZone != null) return namedZone;
      throw const AppError(
        message:
            'Unable to detect your time zone. Restart the app and try again.',
      );
    }
    try {
      final identifier =
          (await _channel.invokeMethod<String>('getLocalTimezone'))?.trim();
      final normalized = _normalizeNativeIdentifier(identifier);
      if (normalized != null) {
        return normalized;
      }
      if (identifier != null && identifier.isNotEmpty) {
        throw const AppError(
          message:
              'Unable to detect your time zone. Restart the app and try again.',
        );
      }
    } on MissingPluginException {
      // Unsupported hosts may still identify a genuine UTC or IANA zone below.
    } on PlatformException {
      // Never substitute a numeric offset or silently change the user's zone.
    }

    final local = DateTime.now();
    final name = local.timeZoneName;
    if (name.contains('/') ||
        (local.timeZoneOffset == Duration.zero &&
            (name == 'UTC' || name == 'GMT'))) {
      final namedZone = _normalizeNativeIdentifier(name);
      if (namedZone != null) return namedZone;
    }
    throw const AppError(
      message:
          'Unable to detect your time zone. Restart the app and try again.',
    );
  }

  static String? _normalizeNativeIdentifier(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (value == 'GMT' || value == 'UTC') {
      return 'UTC';
    }

    if (RegExp(r'^(GMT|UTC)[+-]', caseSensitive: false).hasMatch(value) ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_+/-]{0,79}$').hasMatch(value)) {
      return null;
    }

    return value;
  }
}
