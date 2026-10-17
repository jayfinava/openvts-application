import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/router/route_paths.dart';
import 'package:open_vts/core/theme/open_vts_colors.dart';
import 'package:open_vts/core/utils/date_time_formatter.dart';
import 'package:open_vts/features/admin/models/admin_vehicle_model.dart';
import 'package:open_vts/features/admin/screens/vehicles/widgets/admin_vehicle_card.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/superadmin/controllers/superadmin_providers.dart';
import 'package:open_vts/features/superadmin/models/superadmin_vehicle_model.dart';
import 'package:open_vts/features/superadmin/screens/vehicles/superadmin_vehicles_screen.dart';
import 'package:open_vts/features/user/models/user_vehicle_model.dart';
import 'package:open_vts/features/user/screens/vehicles/widgets/user_vehicle_card.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/widgets/open_vts_vehicle_tracking_button.dart';

const _vehicleId = 'vehicle-17';
const _vehicleImei = '867440060976859';
const _vehicleName = 'Delivery van';

void main() {
  for (final role in [
    UserRole.superadmin,
    UserRole.admin,
    UserRole.team,
    UserRole.user,
    UserRole.subuser,
  ]) {
    testWidgets(
      '${role.name} tracking action opens the selected vehicle route',
      (tester) async {
        final harness = await _mount(tester, role);
        final action = find.byTooltip('Track vehicle');
        await tester.ensureVisible(action);
        expect(action, findsOneWidget);
        expect(tester.getSize(action).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
        final trackingButton = tester.widget<OpenVtsVehicleTrackingButton>(
          find.byType(OpenVtsVehicleTrackingButton),
        );
        expect(trackingButton.onPressed, isNotNull);
        final trackingIcon = tester.widget<Icon>(
          find.descendant(
            of: action,
            matching: find.byIcon(Icons.gps_fixed_rounded),
          ),
        );
        expect(trackingIcon.icon, Icons.gps_fixed_rounded);
        expect(trackingIcon.size, 20);
        expect(trackingIcon.color, OpenVtsColors.brandInk);
        final trackingSurface = tester.widget<Ink>(
          find.byKey(const ValueKey('vehicle-tracking-button')),
        );
        expect(trackingSurface.width, 40);
        expect(trackingSurface.height, 40);
        final decoration = trackingSurface.decoration! as BoxDecoration;
        expect(decoration.color, OpenVtsColors.background);
        expect(decoration.borderRadius, BorderRadius.circular(12));
        expect(decoration.border!.top.color, OpenVtsColors.border);

        await tester.tap(action);
        await tester.pumpAndSettle();

        expect(find.text('Tracking destination'), findsOneWidget);
        expect(harness.trackingState!.pathParameters['vehicleId'], _vehicleId);
        expect(
          harness.trackingState!.uri.queryParameters['imei'],
          _vehicleImei,
        );
        expect(harness.detailState, isNull);
        expect(tester.takeException(), isNull);

        harness.router.pop();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Track vehicle'), findsOneWidget);

        if (role != UserRole.superadmin) {
          await tester.tap(find.text(_vehicleName));
          await tester.pumpAndSettle();
          expect(find.text('Details destination'), findsOneWidget);
          expect(harness.detailState!.pathParameters['vehicleId'], _vehicleId);
        }
      },
    );
  }

  for (final role in [UserRole.team, UserRole.user, UserRole.subuser]) {
    testWidgets(
      '${role.name} with map access disabled has no tracking action',
      (tester) async {
        await _mount(tester, role, canTrack: false);
        expect(find.text(_vehicleName), findsOneWidget);
        expect(find.byTooltip('Track vehicle'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('tracking action disappears when live map access is revoked', (
    tester,
  ) async {
    final harness = await _mount(tester, UserRole.subuser);
    expect(find.byTooltip('Track vehicle'), findsOneWidget);

    harness.auth.replaceUser(_user(UserRole.subuser, canTrack: false));
    await tester.pump();

    expect(find.byTooltip('Track vehicle'), findsNothing);
    expect(find.text(_vehicleName), findsOneWidget);
  });

  testWidgets('unavailable permission snapshot does not expose tracking', (
    tester,
  ) async {
    await _mount(
      tester,
      UserRole.admin,
      access: const MobileAccess.unavailable(),
    );
    expect(find.byTooltip('Track vehicle'), findsNothing);
    expect(find.text(_vehicleName), findsOneWidget);
  });
}

class _Harness {
  _Harness({required this.auth, required this.router});
  final _Auth auth;
  final GoRouter router;
  GoRouterState? trackingState;
  GoRouterState? detailState;
}

Future<_Harness> _mount(
  WidgetTester tester,
  UserRole role, {
  bool canTrack = true,
  MobileAccess? access,
}) async {
  final auth = _Auth(_user(role, canTrack: canTrack, access: access));
  late _Harness harness;
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => _cardPage(role)),
      GoRoute(
        path: '${role.routePrefix}/map/vehicle/:vehicleId',
        builder: (context, state) {
          harness.trackingState = state;
          return const Scaffold(body: Text('Tracking destination'));
        },
      ),
      GoRoute(
        path: '${role.routePrefix}/vehicles/:vehicleId',
        builder: (context, state) {
          harness.detailState = state;
          return const Scaffold(body: Text('Details destination'));
        },
      ),
    ],
  );
  harness = _Harness(auth: auth, router: router);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        appDateFormatterProvider.overrideWithValue(
          const AppDateFormatter(datePattern: 'DD MMM YYYY', use24Hour: false),
        ),
        superadminVehiclePageProvider.overrideWith(
          (ref, query) async => SuperadminVehiclePage(
            items: [SuperadminVehicleRecord.fromJson(_vehicleJson)],
            totalCount: 1,
          ),
        ),
      ],
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return harness;
}

Widget _cardPage(UserRole role) {
  if (role == UserRole.superadmin) {
    return const SuperadminVehiclesScreen();
  }
  return Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Builder(
          builder: (context) {
            if (role.isAdminWorkspace) {
              final vehicle = AdminVehicleListItem.fromJson(_vehicleJson);
              return AdminVehicleCard(
                vehicle: vehicle,
                onTap: () => context.push(
                  RoutePaths.adminVehicleDetailsPath(vehicle.id),
                  extra: vehicle,
                ),
              );
            }
            return UserVehicleCard(
              vehicle: UserVehicleListItem.fromJson(_vehicleJson),
            );
          },
        ),
      ),
    ),
  );
}

const _vehicleJson = <String, dynamic>{
  'id': _vehicleId,
  'name': _vehicleName,
  'plateNumber': 'MH 12 AB 1234',
  'isActive': true,
  'device': {'imei': _vehicleImei},
  'vehicleType': {'name': 'Van'},
};

CurrentUser _user(
  UserRole role, {
  bool canTrack = true,
  MobileAccess? access,
}) =>
    CurrentUser(
      id: 'account-1',
      name: 'Fleet operator',
      email: 'operator@example.test',
      role: role,
      access: access ??
          switch (role) {
            UserRole.team => MobileAccess(
                loaded: true,
                grants: {
                  'vehicles.view': 'TENANT',
                  if (canTrack) 'vehicles.telemetry.view': 'TENANT',
                },
                navigation: {'vehicles', if (canTrack) 'maps'},
              ),
            UserRole.user || UserRole.subuser => MobileAccess(
                loaded: true,
                features: {'vehicles': true, 'maps': canTrack},
              ),
            _ => const MobileAccess.account(),
          },
    );

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(CurrentUser user) : super(AuthState.authenticated(user));

  void replaceUser(CurrentUser user) => state = AuthState.authenticated(user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
