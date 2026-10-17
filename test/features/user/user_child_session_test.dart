import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/auth/models/login_response.dart';
import 'package:open_vts/features/user/controllers/user_child_session_controller.dart';
import 'package:open_vts/features/user/models/user_driver_model.dart';
import 'package:open_vts/features/user/models/user_subuser_model.dart';
import 'package:open_vts/features/user/screens/accounts/drivers/widgets/user_driver_card.dart';
import 'package:open_vts/features/user/screens/accounts/subusers/widgets/user_subuser_card.dart';
import 'package:open_vts/features/user/screens/accounts/widgets/user_child_login_button.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/widgets/open_vts_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final role in [UserRole.driver, UserRole.subuser]) {
    test(
        '${role.name}: exact endpoint and verified child session retain settings',
        () async {
      final harness = _Harness((r) => _payload(role));
      addTearDown(harness.dispose);
      await harness.controller.login('7', role);
      expect(harness.requests.single.uri.path,
          '/api/user/${role == UserRole.driver ? 'drivers' : 'subusers'}/7/login');
      expect(harness.requests.single.method, 'GET');
      expect(harness.requests.single.headers['Cache-Control'], 'no-store');
      expect(harness.auth.sessions.single.user.role, role);
      expect(harness.auth.sessions.single.settings['timezone'], '+05:30');
      expect(harness.auth.sessions.single.refreshToken, 'refresh');
      expect(harness.controller.state, isNull);
    });

    test(
        '${role.name}: rejects wrong role, identity, or incomplete credentials',
        () async {
      for (final payload in [
        _payload(UserRole.admin),
        _payload(role)..['user'] = {'id': '8', 'role': role.name},
        _payload(role)..['refresh_token'] = '',
        _payload(role)..['token'] = '',
      ]) {
        final harness = _Harness((r) => payload);
        try {
          await expectLater(
              harness.controller.login('7', role), throwsException);
          expect(harness.auth.sessions, isEmpty);
          expect(harness.controller.state, isNull);
        } finally {
          harness.dispose();
        }
      }
    });

    testWidgets(
        '${role.name}: account card offers one Login action to its owner',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final harness = _Harness((r) => _payload(role), cache: LocalCache(prefs));
      addTearDown(harness.dispose);
      final child = role == UserRole.driver
          ? UserDriverCard(
              driver: UserDriver.fromJson({
              'id': 7,
              'name': 'Driver',
              'username': 'driver',
              'isActive': true
            }))
          : UserSubUserCard(
              subUser: UserSubUser.fromJson(
                  {'uid': 7, 'name': 'Sub User', 'isActive': true}),
              isTogglingStatus: false,
              onToggleStatus: (_) {});
      await tester.pumpWidget(UncontrolledProviderScope(
          container: harness.container,
          child: MaterialApp(
              theme: OpenVtsTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SingleChildScrollView(child: child)))));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      await tester.tap(find.text('Login'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });
      await tester.pumpAndSettle();
      expect(harness.auth.sessions.single.user.role, role);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('a backend outage preserves the owner and allows an explicit retry',
      () async {
    var attempts = 0;
    final harness = _Harness((request) {
      if (attempts++ == 0) {
        throw DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: request, statusCode: 503));
      }
      return _payload(UserRole.driver);
    });
    addTearDown(harness.dispose);
    await expectLater(harness.controller.login('7', UserRole.driver),
        throwsA(isA<DioException>()));
    expect(harness.auth.state.role, UserRole.user);
    expect(harness.auth.sessions, isEmpty);
    expect(harness.controller.state, isNull);
    await harness.controller.login('7', UserRole.driver);
    expect(harness.auth.sessions, hasLength(1));
    expect(harness.requests, hasLength(2));
  });

  testWidgets(
      'Login is disabled for inactive accounts and hidden from child or demo sessions',
      (tester) async {
    final harness = _Harness((r) => _payload(UserRole.driver));
    addTearDown(harness.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: harness.container,
        child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
                body: UserChildLoginButton(
                    id: '7', role: UserRole.driver, isActive: false)))));
    await tester.pumpAndSettle();
    expect(tester.widget<OpenVtsButton>(find.byType(OpenVtsButton)).onPressed,
        isNull);
    harness.auth.change(_user(UserRole.subuser, '1'));
    await tester.pump();
    expect(find.text('Login'), findsNothing);
    harness.auth.change(_user(UserRole.user, '1'), demo: true);
    await tester.pump();
    expect(find.text('Login'), findsNothing);
    expect(harness.requests, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('one pending transition blocks duplicate and competing account requests',
      () async {
    final pending = Completer<dynamic>();
    final harness = _Harness((r) => pending.future);
    addTearDown(harness.dispose);
    final first = harness.controller.login('7', UserRole.driver);
    await harness.started.future;
    await harness.controller.login('7', UserRole.driver);
    await harness.controller.login('8', UserRole.subuser);
    expect(harness.requests, hasLength(1));
    pending.complete(_payload(UserRole.driver));
    await first;
    expect(harness.auth.sessions, hasLength(1));
  });

  test('a response from an earlier parent cannot replace a changed account',
      () async {
    final pending = Completer<dynamic>();
    final harness = _Harness((r) => pending.future);
    addTearDown(harness.dispose);
    final result = harness.controller.login('7', UserRole.subuser);
    final rejected = expectLater(result, throwsException);
    await harness.started.future;
    harness.auth.change(_user(UserRole.user, '2'));
    pending.complete(_payload(UserRole.subuser));
    await rejected;
    expect(harness.auth.sessions, isEmpty);
  });

  test('unmount cancels an outstanding request without installing credentials',
      () async {
    final pending = Completer<dynamic>();
    final harness = _Harness((r) => pending.future);
    final result = harness.controller.login('7', UserRole.driver);
    final rejected = expectLater(result, throwsA(isA<DioException>()));
    await harness.started.future;
    harness.dispose();
    pending.complete(_payload(UserRole.driver));
    await rejected;
    expect(harness.auth.sessions, isEmpty);
  });

  for (final role in [
    UserRole.admin,
    UserRole.team,
    UserRole.subuser,
    UserRole.driver
  ]) {
    test('${role.name} cannot use owner-only child login', () async {
      final harness = _Harness((r) => _payload(UserRole.driver), parent: role);
      addTearDown(harness.dispose);
      await expectLater(
          harness.controller.login('7', UserRole.driver), throwsException);
      expect(harness.requests, isEmpty);
    });
  }
}

CurrentUser _user(UserRole role, String id) =>
    CurrentUser(id: id, name: 'Account', email: '', role: role);
Map<String, dynamic> _payload(UserRole role) => {
      'token': 'access',
      'refresh_token': 'refresh',
      'user': {'id': '7', 'role': role.name, 'name': 'Child'},
      'settings': {'timezone': '+05:30'},
    };

class _Harness {
  _Harness(FutureOr<dynamic> Function(RequestOptions) route,
      {UserRole parent = UserRole.user, LocalCache? cache}) {
    auth = _Auth(_user(parent, '1'));
    dio = Dio(BaseOptions(baseUrl: 'https://fleet.example/api'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) async {
      requests.add(r);
      if (!started.isCompleted) started.complete();
      try {
        h.resolve(Response(requestOptions: r, statusCode: 200, data: {
          'status': 'success',
          'data': {'action': true, 'data': await route(r)},
        }));
      } catch (error) {
        h.reject(error is DioException
            ? error
            : DioException(requestOptions: r, error: error));
      }
    }));
    container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => auth),
      apiClientProvider.overrideWithValue(ApiClient(dio)),
      if (cache != null) localCacheProvider.overrideWithValue(cache),
    ]);
    container.listen(userChildSessionControllerProvider, (_, __) {});
    controller = container.read(userChildSessionControllerProvider.notifier);
  }
  late final _Auth auth;
  late final Dio dio;
  late final ProviderContainer container;
  late final UserChildSessionController controller;
  final requests = <RequestOptions>[];
  final started = Completer<void>();
  void dispose() {
    container.dispose();
    dio.close(force: true);
  }
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(CurrentUser user) : super(AuthState.authenticated(user));
  final sessions = <LoginResponse>[];
  void change(CurrentUser user, {bool demo = false}) =>
      state = AuthState.authenticated(user, isDemo: demo);
  @override
  Future<void> switchToChildSession(LoginResponse response) async {
    sessions.add(response);
    change(response.user);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
