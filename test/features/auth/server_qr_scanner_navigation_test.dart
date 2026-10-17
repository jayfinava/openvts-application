import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/router/route_paths.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/screens/api_base_url_scanner_screen.dart';
import 'package:open_vts/features/auth/screens/api_base_url_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('manual configuration opens from scanner without a camera',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    dotenv.testLoad(fileInput: 'API_BASE_URL=https://default.example/api');
    SharedPreferences.setMockInitialValues({});
    final server = ApiBaseUrlController(
      LocalCache(await SharedPreferences.getInstance()),
    );
    final auth = _UnauthenticatedAuth();
    final router = GoRouter(
      initialLocation: RoutePaths.login,
      routes: [
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(RoutePaths.apiBaseUrlScanner),
              child: const Text('Open scanner'),
            ),
          ),
        ),
        GoRoute(
          path: RoutePaths.apiBaseUrlScanner,
          builder: (context, state) => const ApiBaseUrlScannerScreen(),
        ),
        GoRoute(
          path: RoutePaths.apiBaseUrlSettings,
          builder: (context, state) => const ApiBaseUrlSettingsScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiBaseUrlProvider.overrideWith((ref) => server),
        authControllerProvider.overrideWith((ref) => auth),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open scanner'));
    await tester.pumpAndSettle();
    expect(find.text('Configure manually'), findsOneWidget);
    expect(find.text('Camera scanning is unavailable on this device.'),
        findsOneWidget);

    await tester.tap(find.text('Configure manually'));
    await tester.pumpAndSettle();
    expect(find.byType(ApiBaseUrlSettingsScreen), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'https://new.example/api');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(server.state, 'https://new.example/api');
    expect(auth.logoutCalls, 1);
    expect(find.text('Open scanner'), findsOneWidget);
    expect(find.byType(ApiBaseUrlScannerScreen), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}

class _UnauthenticatedAuth extends StateNotifier<AuthState>
    implements AuthController {
  _UnauthenticatedAuth() : super(const AuthState.unauthenticated());

  int logoutCalls = 0;

  @override
  Future<void> logoutAllRoles({
    bool deregisterPush = true,
    bool showLoading = true,
  }) async {
    logoutCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
