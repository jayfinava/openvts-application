import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/router/app_router.dart';
import 'package:open_vts/core/router/route_paths.dart';
import 'package:open_vts/features/admin/screens/map/admin_map_screen.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/live_map/models/live_map_vehicle_target.dart';
import 'package:open_vts/features/superadmin/screens/map/superadmin_map_screen.dart';
import 'package:open_vts/features/user/screens/map/user_map_screen.dart';
import 'package:open_vts/shared/models/user_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final paths = [
    RoutePaths.superadminVehicleTrackingPath,
    RoutePaths.adminVehicleTrackingPath,
    RoutePaths.userVehicleTrackingPath,
  ];
  test('tracking links preserve vehicle identity and optional IMEI', () {
    for (final path in paths) {
      final uri = Uri.parse(path(' vehicle / 42 ', imei: ' imei+42 '));
      expect(uri.pathSegments.last, 'vehicle / 42');
      expect(uri.queryParameters['imei'], 'imei+42');
      final withoutImei = Uri.parse(path('42'));
      expect(withoutImei.pathSegments.last, '42');
      expect(withoutImei.hasQuery, isFalse);
    }
  });

  test(
    'tracking routes retain the main map permission for every workspace',
    () {
      for (final role in [
        UserRole.superadmin,
        UserRole.admin,
        UserRole.team,
        UserRole.user,
        UserRole.subuser,
      ]) {
        final access = _access(role);
        final prefix = role.routePrefix;
        expect(
          access.canAccessPath(role, '$prefix/map/vehicle/42?imei=i42'),
          isTrue,
        );
        expect(
          access.canAccessPath(role, '$prefix/map/vehicle/42/extra'),
          isFalse,
        );
        expect(
          const MobileAccess.unavailable().canAccessPath(
            role,
            '$prefix/map/vehicle/42',
          ),
          isFalse,
        );
      }
      for (final role in [UserRole.user, UserRole.subuser, UserRole.team]) {
        final denied = _access(role, maps: false);
        expect(
          denied.canAccessPath(role, '${role.routePrefix}/map/vehicle/42'),
          isFalse,
        );
      }
      expect(
        _access(
          UserRole.user,
        ).canAccessPath(UserRole.user, '/admin/map/vehicle/42'),
        isFalse,
      );
      expect(
        const MobileAccess.account().canAccessPath(
          UserRole.driver,
          '/driver/map/vehicle/42',
        ),
        isFalse,
      );
    },
  );

  testWidgets('production routes build the same role maps with a target', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [authControllerProvider.overrideWith((ref) => _Auth())],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    addTearDown(router.dispose);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));
    final routes = _allRoutes(router.configuration.routes).toList();
    for (final path in paths) {
      final uri = Uri.parse(path('42', imei: 'imei42'));
      final matches = router.configuration.findMatch(uri);
      expect(matches.error, isNull);
      expect(matches.pathParameters['vehicleId'], '42');
      final route = routes.singleWhere(
        (route) => route.path == matches.fullPath,
      );
      final state = GoRouterState(
        router.configuration,
        uri: uri,
        matchedLocation: uri.path,
        fullPath: matches.fullPath,
        pathParameters: matches.pathParameters,
        pageKey: const ValueKey('tracking-route'),
      );
      final screen = route.builder!(context, state);
      final LiveMapVehicleTarget? target = switch (screen) {
        SuperadminMapScreen(:final vehicleTarget) => vehicleTarget,
        AdminMapScreen(:final vehicleTarget) => vehicleTarget,
        UserMapScreen(:final vehicleTarget) => vehicleTarget,
        _ => throw StateError('Tracking route must use the existing role map'),
      };
      expect(target?.vehicleId, '42');
      expect(target?.imei, 'imei42');
    }
    for (final path in [
      RoutePaths.superadminMap,
      RoutePaths.adminMap,
      RoutePaths.userMap,
    ]) {
      final route = routes.singleWhere((route) => route.path == path);
      final screen = route.builder!(
        context,
        GoRouterState(
          router.configuration,
          uri: Uri.parse(path),
          matchedLocation: path,
          fullPath: path,
          pathParameters: const {},
          pageKey: const ValueKey('fleet-route'),
        ),
      );
      final target = switch (screen) {
        SuperadminMapScreen(:final vehicleTarget) => vehicleTarget,
        AdminMapScreen(:final vehicleTarget) => vehicleTarget,
        UserMapScreen(:final vehicleTarget) => vehicleTarget,
        _ => throw StateError('Unexpected fleet map'),
      };
      expect(target, isNull);
    }
  });
}

Iterable<GoRoute> _allRoutes(List<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute) yield route;
    yield* _allRoutes(route.routes);
  }
}

MobileAccess _access(UserRole role, {bool maps = true}) => switch (role) {
  UserRole.team => MobileAccess.team({
    'grants': {
      'vehicles.view': 'ASSIGNED',
      if (maps) 'vehicles.telemetry.view': 'ASSIGNED',
    },
    'navigation': ['vehicles', if (maps) 'maps'],
  }),
  UserRole.user || UserRole.subuser => MobileAccess.user({
    'features': {
      for (final key in MobileAccess.userFeatures) key: key != 'maps' || maps,
    },
    'reports': {for (final key in MobileAccess.userReports) key: true},
  }),
  _ => const MobileAccess.account(),
};

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth()
    : super(
        const AuthState.authenticated(
          CurrentUser(
            id: 'router-test',
            name: 'Router test',
            email: '',
            role: UserRole.admin,
            access: MobileAccess.account(),
          ),
        ),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
