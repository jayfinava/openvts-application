import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_endpoints.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/api_options.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/models/user_role.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/models/login_response.dart';

/// One account transition at a time across both account lists. The existing
/// session stack verifies the child profile and keeps the exact parent session.
final userChildSessionControllerProvider =
    StateNotifierProvider.autoDispose<UserChildSessionController, String?>(
        (ref) {
  final controller = UserChildSessionController(ref);
  ref.onDispose(controller.cancel);
  return controller;
});

class UserChildSessionController extends StateNotifier<String?> {
  UserChildSessionController(this._ref) : super(null);
  final Ref _ref;
  final CancelToken _cancelToken = CancelToken();

  void cancel() => _cancelToken.cancel('Account list closed');

  Future<void> login(String id, UserRole role) async {
    if (state != null) return;
    final parent = _ref.read(authControllerProvider);
    if (!parent.isRealSession || parent.role != UserRole.user) {
      throw const ApiException(
          message: 'Sign in as the owner to access this account.');
    }
    if (id.trim().isEmpty ||
        (role != UserRole.driver && role != UserRole.subuser)) {
      throw const ApiException(message: 'This account is unavailable.');
    }
    final auth = _ref.read(authControllerProvider.notifier);
    final storage = _ref.read(tokenStorageProvider);
    final sessionGeneration = storage.sessionGeneration;
    state = '${role.name}:$id';
    try {
      final response = await _ref.read(apiClientProvider).get<LoginResponse>(
        role == UserRole.driver
            ? ApiEndpoints.user.driverLogin(id)
            : ApiEndpoints.user.subuserLogin(id),
        options: normalWriteOptions().copyWith(headers: {
          'Cache-Control': 'no-store',
          'Pragma': 'no-cache',
        }),
        cancelToken: _cancelToken,
        parser: (json) {
          if (json is! Map<String, dynamic>) {
            throw const FormatException('Invalid account session');
          }
          return LoginResponse.fromJson(json);
        },
      );
      final child = response.data;
      if (child.user.id != id ||
          child.user.role != role ||
          child.accessToken.trim().isEmpty ||
          child.refreshToken.trim().isEmpty) {
        throw const ApiException(
            message: 'The server returned an invalid account session.');
      }
      if (!mounted || _cancelToken.isCancelled) return;
      final current = _ref.read(authControllerProvider);
      if (!current.isRealSession ||
          storage.sessionGeneration != sessionGeneration ||
          current.user?.id != parent.user?.id ||
          current.role != parent.role) {
        throw const ApiException(
            message: 'Your account changed. Try signing in again.');
      }
      await auth.switchToChildSession(child);
    } finally {
      if (mounted) state = null;
    }
  }
}
