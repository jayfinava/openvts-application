import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../controllers/auth_controller.dart';

/// Accept a plain API URL or a QR JSON object containing `apiBaseUrl`.
String? apiBaseUrlFromQrCode(String? rawValue) {
  final raw = rawValue?.trim();
  if (raw == null || raw.isEmpty) return null;

  String candidate = raw;
  if (raw.startsWith('{')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['apiBaseUrl'] is! String) return null;
      candidate = decoded['apiBaseUrl'] as String;
    } on FormatException {
      return null;
    }
  }

  if (AppConfig.validateApiBaseUrl(candidate) != null) return null;
  return ApiBaseUrlController.normalizeUrl(candidate);
}

/// Both QR scanning and manual editing use the same server-switch sequence.
Future<String> configureApiBaseUrl(
  WidgetRef ref,
  String value, {
  bool reset = false,
}) async {
  final controller = ref.read(apiBaseUrlProvider.notifier);
  final next =
      reset ? controller.defaultUrl : ApiBaseUrlController.normalizeUrl(value);
  final validationError = AppConfig.validateApiBaseUrl(next);
  if (validationError != null) throw FormatException(validationError);

  if (next != ref.read(apiBaseUrlProvider)) {
    // A token from one server must never be sent to another server.
    await ref.read(authControllerProvider.notifier).logoutAllRoles(
          deregisterPush: false,
          showLoading: false,
        );
  }

  if (reset) {
    await controller.resetToDefault();
  } else {
    await controller.saveCustomUrl(next);
  }
  return next;
}
