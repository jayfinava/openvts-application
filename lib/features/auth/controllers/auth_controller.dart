import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/mobile_push_controller.dart';
import '../../../core/notifications/mobile_push_perf.dart';
import '../../../core/performance/open_vts_perf.dart';
import '../../../core/providers/app_preferences_provider.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/demo/demo_mode_store.dart';
import '../../../core/demo/demo_session.dart';
import '../../../core/demo/demo_session_service.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/user_role.dart';
import '../models/current_user.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../services/auth_service.dart';
import 'auth_state.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    authService: ref.watch(authServiceProvider),
    mobilePushController: ref.watch(mobilePushControllerProvider.notifier),
    tokenStorage: ref.watch(tokenStorageProvider),
    demoModeStore: ref.watch(demoModeStoreProvider),
    demoSessionService: ref.watch(demoSessionServiceProvider),
    appPreferencesCtrl: ref.watch(appLocalizationPreferencesProvider.notifier),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthService authService,
    required MobilePushController mobilePushController,
    required TokenStorage tokenStorage,
    required DemoModeStore demoModeStore,
    required DemoSessionService demoSessionService,
    required AppLocalizationPreferencesController appPreferencesCtrl,
  })  : _authService = authService,
        _mobilePushController = mobilePushController,
        _tokenStorage = tokenStorage,
        _demoModeStore = demoModeStore,
        _demoSessionService = demoSessionService,
        _appPreferencesCtrl = appPreferencesCtrl,
        super(const AuthState.initial());

  final AuthService _authService;
  final MobilePushController _mobilePushController;
  final TokenStorage _tokenStorage;
  final DemoModeStore _demoModeStore;
  final DemoSessionService _demoSessionService;
  final AppLocalizationPreferencesController _appPreferencesCtrl;

  CurrentUser? get currentUser => state.user;

  Future<void> restoreSession() {
    return OpenVtsPerf.traceAsync('auth.restore', () async {
      state = const AuthState.loading();
      final stopwatch =
          (kDebugMode || kProfileMode) ? (Stopwatch()..start()) : null;
      mobilePushPerfLog('auth_restore start');
      await _setStateFromActiveSession();
      if (stopwatch != null) {
        mobilePushPerfLog(
          'auth_restore end (${stopwatch.elapsedMilliseconds}ms)',
        );
      }
    });
  }

  Future<void> login({
    required String identifier,
    required String password,
  }) {
    return OpenVtsPerf.traceAsync('auth.login', () async {
      state = const AuthState.loading();

      try {
        final response = await _authService.login(
          LoginRequest(identifier: identifier, password: password),
        );
        await setSession(response);
      } catch (error) {
        _setUnauthenticated(errorMessage: error.toString());
      }
    });
  }

  Future<void> enterDemo() {
    return OpenVtsPerf.traceAsync('auth.demo', () async {
      state = const AuthState.loading();
      try {
        final session = await _demoSessionService.openSession();
        if (!session.permissions.readOnly) {
          throw const FormatException(
            'The server did not return a read-only demo session.',
          );
        }
        await _demoModeStore.enable(session);
        _setDemoSession(session);
      } catch (error) {
        await _demoModeStore.clear();
        _setUnauthenticated(errorMessage: error.toString());
      }
    });
  }

  Future<String> requestPasswordReset(String identifier) {
    return _authService.requestPasswordReset(identifier);
  }

  Future<String> resetPassword({
    required String token,
    required String newPassword,
  }) {
    return _authService.resetPassword(
      token: token,
      newPassword: newPassword,
    );
  }

  Future<void> setSession(LoginResponse response) {
    return OpenVtsPerf.traceAsync('auth.setSession', () async {
      await _demoModeStore.clear();
      await _tokenStorage.saveSessionForRole(
        role: response.user.role,
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        currentUserJson: jsonEncode(response.user.toJson()),
      );
      await _setStateFromActiveSession();
    });
  }

  Future<void> replaceCurrentUser(CurrentUser user) async {
    if (state.isDemo) {
      state = AuthState.authenticated(
        user.copyWith(role: UserRole.user),
        isDemo: true,
      );
      return;
    }

    final activeSession = await _tokenStorage.getActiveSession();
    if (activeSession == null) {
      _setUnauthenticated();
      return;
    }

    final role = activeSession.role;
    await _tokenStorage.saveSessionForRole(
      role: role,
      accessToken: activeSession.accessToken,
      refreshToken: activeSession.refreshToken,
      currentUserJson: jsonEncode(user.copyWith(role: role).toJson()),
    );
    await _setStateFromActiveSession();
  }

  Future<UserRole?> logout() async {
    return logoutActiveRole();
  }

  Future<UserRole?> logoutActiveRole() async {
    if (state.isDemo) {
      state = const AuthState.loading();
      await _demoModeStore.clear();
      await _setStateFromActiveSession();
      return UserRole.user;
    }

    final activeRole =
        state.user?.role ?? await _tokenStorage.getActiveRoleByPriority();
    if (activeRole == null) {
      _setUnauthenticated();
      return null;
    }

    await _deregisterPushForCurrentSession();

    state = const AuthState.loading();

    try {
      await _authService.logout();
    } finally {
      await _tokenStorage.clearSessionForRole(activeRole);
    }

    await _setStateFromActiveSession();
    return activeRole;
  }

  Future<void> logoutAllRoles() async {
    await _deregisterPushForCurrentSession();

    state = const AuthState.loading();
    await _demoModeStore.clear();
    await _tokenStorage.clearAllSessions();
    _setUnauthenticated();
  }

  Future<void> _setStateFromActiveSession() async {
    final demoSession = _demoModeStore.cachedSession;
    if (_demoModeStore.isEnabled && demoSession != null) {
      _setDemoSession(demoSession);
      return;
    }
    if (_demoModeStore.isEnabled || demoSession != null) {
      await _demoModeStore.clear();
    }

    final session = await _tokenStorage.getActiveSession();
    if (session == null) {
      _setUnauthenticated();
      return;
    }

    state = AuthState.authenticated(session.user);
    _mobilePushController.updateAuthenticationState(isAuthenticated: true);

    // Rehydrate localization preferences from LocalCache on session restore
    _appPreferencesCtrl.rehydrate();
  }

  void _setDemoSession(DemoSession session) {
    final user = CurrentUser(
      id: session.user.id,
      name: session.user.name,
      email: session.user.email,
      role: UserRole.user,
      username: 'demo.fleet',
      phoneNumber: '+1 555 010 0000',
      mobilePrefix: '+1',
      mobileNumber: '5550100000',
      accountStatus: 'active',
      isVerified: true,
      addressLine: '100 Demo Fleet Avenue',
      countryCode: 'US',
      stateCode: 'NY',
      cityName: 'New York City',
      pincode: '10001',
    );
    state = AuthState.authenticated(user, isDemo: true);
    _mobilePushController.updateAuthenticationState(isAuthenticated: false);
    _appPreferencesCtrl.rehydrate();
  }

  void _setUnauthenticated({String? errorMessage}) {
    state = AuthState.unauthenticated(errorMessage: errorMessage);
    _mobilePushController.updateAuthenticationState(isAuthenticated: false);
  }

  Future<void> _deregisterPushForCurrentSession() async {
    if (state.isDemo) {
      _mobilePushController.updateAuthenticationState(isAuthenticated: false);
      return;
    }

    try {
      final session = await _tokenStorage.getActiveSession();
      if (session == null) {
        _mobilePushController.updateAuthenticationState(
          isAuthenticated: false,
        );
        return;
      }

      _mobilePushController.updateAuthenticationState(isAuthenticated: true);
      await _ignorePushFailure(_mobilePushController.deregisterCurrentToken);
    } catch (_) {
      // Push deregistration must never block logout.
    }
  }

  Future<void> _ignorePushFailure(Future<dynamic> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Push token sync must not change auth outcomes.
    }
  }
}
