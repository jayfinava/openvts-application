import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/access/workspace_scope_provider.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/features/admin/controllers/admin_providers.dart';
import 'package:open_vts/features/admin/models/admin_inventory_model.dart';
import 'package:open_vts/features/admin/models/admin_vehicle_state.dart';
import 'package:open_vts/features/admin/screens/users/widgets/admin_user_vehicles_tab.dart';
import 'package:open_vts/features/admin/screens/vehicles/admin_vehicles_screen.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/superadmin/controllers/superadmin_providers.dart';
import 'package:open_vts/features/superadmin/screens/administrators/widgets/admin_details_credit_history_tab.dart';
import 'package:open_vts/features/user/controllers/user_providers.dart';
import 'package:open_vts/features/user/screens/vehicles/user_vehicles_screen.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/paging/server_list_pager.dart';
import 'package:open_vts/shared/paging/server_list_pagination.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _paths = [
  '/superadmin/creditlogs/42',
  '/superadmin/adminvehicles/42',
  '/admin/linkvehicles/42',
  '/admin/vehicles',
  '/admin/drivers',
  '/admin/devices',
  '/admin/simcards',
  '/user/vehicles',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));

  for (final path in ['/admin/vehicles', '/user/vehicles']) {
    for (final direct in [false, true]) {
      test('$path loads backend vehicle envelopes (direct: $direct)', () async {
        final h = _Harness(path, directVehicleEnvelope: direct);
        addTearDown(h.dispose);
        final (pager, controller) = await h.open();
        await _until(() => !pager.loading);
        expect(pager.error, isNull);
        expect(controller.state.errorMessage, isNull);
        expect(controller.state.vehicles, hasLength(20));
        expect(pager.meta!.total, 10000);
        expect(h.targetRequests.single.uri.path, '/api$path');
        expect(h.targetRequests.single.queryParameters['page'], 1);
        expect(h.targetRequests.single.queryParameters['limit'], 20);
        await pager.goToPage(2);
        expect(controller.state.vehicles.first.id, '21');
        expect(controller.state.vehicles, hasLength(20));
        expect(pager.meta!.page, 2);
        await pager.change(page: 1, search: 'row 9999');
        expect(controller.state.vehicles.single.id, '9999');
        expect(pager.meta!.total, 1);
        h.emptyVehicles = true;
        await pager.load();
        expect(pager.error, isNull);
        expect(controller.state.vehicles, isEmpty);
        expect(pager.meta!.total, 0);
      });
    }

    testWidgets('$path screen loads and navigates to the next backend page',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final cache = LocalCache(await SharedPreferences.getInstance());
      final h = _Harness(path, cache: cache);
      addTearDown(h.dispose);
      await tester.pumpWidget(h.app(
          path.startsWith('/admin')
              ? const AdminVehiclesScreen()
              : const UserVehiclesScreen(),
          scroll: false));
      await tester.pumpAndSettle();
      expect(find.text('row 1'), findsOneWidget);
      expect(h.targetRequests, hasLength(1));
      final nextPage = find.byTooltip('Next page').hitTestable();
      await tester.scrollUntilVisible(nextPage, 500,
          scrollable: find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down)
              .last);
      await tester.tap(nextPage);
      await tester.pumpAndSettle();
      expect(h.targetRequests, hasLength(2));
      expect(h.targetRequests.last.queryParameters['page'], 2);
      expect(find.text('row 21'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final path in _paths) {
    test(
        '$path production provider keeps one page and performs global backend search',
        () async {
      final h = _Harness(path);
      addTearDown(h.dispose);
      final (pager, controller) = await h.open();
      await _until(() => pager.meta != null);
      expect(h.targetRequests, hasLength(1));
      expect(h.targetRequests.single.queryParameters['page'], 1);
      expect(h.targetRequests.single.queryParameters['limit'], 20);
      expect(pager.meta!.total, 10000);
      expect(pager.items, hasLength(20));
      if (path.contains('creditlogs')) {
        expect(h.targetRequests.single.queryParameters['sortBy'], 'createdAt');
        expect(h.targetRequests.single.queryParameters['sortDir'], 'desc');
        expect(controller.state.creditLogs.first.balanceAfter, 91337);
      }
      await pager.goToPage(2);
      expect(h.targetRequests, hasLength(2));
      expect(pager.items, hasLength(20));
      expect(pager.meta!.page, 2);
      if (path == '/admin/vehicles') {
        expect(controller.state.visibleVehicles.first.id, '21');
      }
      if (path == '/admin/drivers') {
        expect(controller.state.visibleDrivers.first.id, '21');
      }
      if (path == '/admin/devices') {
        expect(controller.state.visibleDevices.first.id, '21');
      }
      if (path == '/admin/simcards') {
        expect(controller.state.visibleSimCards.first.id, '21');
      }
      await pager.change(page: 1, search: 'row 9999');
      expect(pager.items, hasLength(1));
      expect(pager.meta!.total, 1);
      expect(h.targetRequests.last.queryParameters['search'], 'row 9999');
      expect(h.targetRequests, hasLength(3));
      // Credit balances come from the complete server ledger even on a search.
      if (path.contains('creditlogs')) {
        expect(controller.state.creditLogs.single.balanceAfter, 719337);
      }
      if (path == '/admin/linkvehicles/42') {
        expect(
            h.requests.where((r) => r.uri.path.endsWith('/unlinkvehicles/42')),
            isEmpty);
        await controller.availableVehiclesPager.load();
        expect(controller.state.availableVehicles, hasLength(20));
        expect(controller.state.availableVehiclesPagination.total, 10000);
      }
    });
  }

  test(
      'UI controller search and filters issue bounded requests and reset the server page',
      () async {
    final h = _Harness('/admin/vehicles');
    addTearDown(h.dispose);
    final (pager, controller) = await h.open();
    await _until(() => pager.meta != null);
    await pager.goToPage(4);
    controller.setSearchQuery('row 9');
    controller.setSearchQuery('row 9999');
    await Future<void>.delayed(const Duration(milliseconds: 420));
    expect(h.targetRequests, hasLength(3));
    expect(controller.state.visibleVehicles.single.id, '9999');
    controller.clearFilters();
    await _until(() => !pager.loading);
    controller.setStatusFilter(AdminVehicleStatusFilter.inactive);
    await _until(() => !pager.loading);
    expect(jsonDecode(h.targetRequests.last.queryParameters['filters']),
        {'status': false});
    expect(h.targetRequests.last.queryParameters['page'], 1);
  });

  test(
      'equivalent auth refresh preserves the current page and does not refetch',
      () async {
    final h = _Harness('/admin/vehicles');
    addTearDown(h.dispose);
    final (pager, controller) = await h.open();
    await _until(() => pager.meta != null);
    await pager.goToPage(3);
    h.auth.refresh();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(h.container.read(adminVehiclesControllerProvider.notifier),
        same(controller));
    expect(pager.meta!.page, 3);
    expect(h.targetRequests, hasLength(2));
  });

  test(
      'a paged credit response without ledger balances never invents balances from the current page',
      () async {
    final h =
        _Harness('/superadmin/creditlogs/42', missingLedgerBalances: true);
    addTearDown(h.dispose);
    final (pager, controller) = await h.open();
    expect(pager.meta, isNull);
    expect(pager.error, isNotNull);
    expect(controller.state.creditLogs, isEmpty);
    expect(h.targetRequests, hasLength(1));
  });

  testWidgets(
      'credit history displays the backend ledger balance for a global search result',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final h = _Harness('/superadmin/creditlogs/42',
        cache: LocalCache(await SharedPreferences.getInstance()));
    addTearDown(h.dispose);
    final (pager, _) =
        await tester.runAsync(h.open) ?? (throw StateError('No controller'));
    await tester.runAsync(() => pager.change(page: 1, search: 'row 9999'));
    await tester
        .pumpWidget(h.app(const AdminDetailsCreditHistoryTab(adminId: '42')));
    await tester.pumpAndSettle();
    expect(find.textContaining('719337'), findsAtLeastNWidgets(1));
    expect(find.textContaining('null'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'assignment drawer searches and pages remotely, retaining multiple selections',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final h = _Harness('/admin/linkvehicles/42',
        cache: LocalCache(await SharedPreferences.getInstance()));
    addTearDown(h.dispose);
    final (_, controller) =
        await tester.runAsync(h.open) ?? (throw StateError('No controller'));
    await tester.pumpWidget(h.app(const AdminUserVehiclesTab(userId: '42')));
    await tester.pumpAndSettle();
    expect(h.requests.where((r) => r.uri.path.endsWith('/unlinkvehicles/42')),
        isEmpty);
    expect(find.textContaining('null'), findsNothing);
    await tester.tap(find.text('Assign Vehicle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final available =
        controller.availableVehiclesPager as ServerListPager<dynamic>;
    await tester.runAsync(() => _until(() => available.meta != null));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet).last;
    await tester
        .tap(find.descendant(of: sheet, matching: find.text('row 1')).last);
    final next =
        find.descendant(of: sheet, matching: find.byTooltip('Next page'));
    final scroll = find
        .descendant(
            of: sheet,
            matching: find.byWidgetPredicate((w) =>
                w is Scrollable && w.axisDirection == AxisDirection.down))
        .first;
    await tester.scrollUntilVisible(next, 250, scrollable: scroll);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(available.meta?.page, 2);
    await tester
        .tap(find.descendant(of: sheet, matching: find.text('row 21')).last);
    final search = find.descendant(
        of: sheet,
        matching: find.byWidgetPredicate((w) =>
            w is TextField &&
            w.decoration?.hintText == 'Search available vehicles'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    addTearDown(tester.view.resetViewInsets);
    await tester.enterText(search, 'row 9999');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(available.items.single.id, '9999');
    await tester
        .tap(find.descendant(of: sheet, matching: find.text('row 9999')).last);
    await tester
        .tap(find.descendant(of: sheet, matching: find.text('Assign')).last);
    await tester.pumpAndSettle();
    final assigned = h.requests.where(
        (r) => r.method == 'POST' && r.uri.path.endsWith('/linkvehicles/42'));
    expect(assigned.map((r) => (r.data as Map)['vehicleId']).toSet(),
        {'1', '21', '9999'});
    expect(
        h.requests
            .where((r) =>
                r.method == 'GET' && r.uri.path.endsWith('/unlinkvehicles/42'))
            .every((r) => r.queryParameters['limit'] == 20),
        true);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
        'page controls stay bounded and usable at 320px, ${scale}x text',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var selected = 0;
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                  body: ServerListPagination(
                      meta: const ListPageMeta(
                          page: 250, limit: 20, total: 10000),
                      loading: false,
                      onPageChanged: (page) async {
                        selected = page;
                      })))));
      await tester.pumpAndSettle();
      final dropdown =
          tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>));
      expect(dropdown.items, hasLength(7));
      dropdown.onChanged!(500);
      await tester.pumpAndSettle();
      expect(selected, 500);
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _until(bool Function() ready) async {
  for (var i = 0; i < 80 && !ready(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(ready(), true);
}

class _Harness {
  _Harness(this.path,
      {LocalCache? cache,
      bool missingLedgerBalances = false,
      bool directVehicleEnvelope = false}) {
    final role = path.startsWith('/superadmin')
        ? UserRole.superadmin
        : path.startsWith('/user/')
            ? UserRole.user
            : UserRole.admin;
    auth = _Auth(CurrentUser(
        id: '1',
        name: 'Owner',
        email: '',
        role: role,
        access: const MobileAccess.account()));
    dio = Dio(BaseOptions(baseUrl: 'https://fleet.example/api'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) {
      requests.add(r);
      final q = r.queryParameters;
      final vehicleDirectory = r.uri.path == '/api/admin/vehicles' ||
          r.uri.path == '/api/user/vehicles';
      dynamic data = {'uid': 42, 'id': 42, 'name': 'Account'};
      if (q.containsKey('page') && r.uri.path != '/api/admin/payments') {
        final page = q['page'] as int, limit = q['limit'] as int;
        final search = q['search'] == 'row 9999';
        final start = (page - 1) * limit;
        final rows = [
          for (var i = 0;
              i <
                  (vehicleDirectory && emptyVehicles
                      ? 0
                      : search
                          ? 1
                          : limit);
              i++)
            _row(search ? 9999 : start + i + 1)
        ];
        if (missingLedgerBalances) {
          for (final row in rows) {
            row.remove('balanceAfter');
          }
        }
        data = {
          r.uri.path.contains('creditlogs')
              ? 'logs'
              : vehicleDirectory
                  ? 'vehicles'
                  : 'data': rows,
          'pagination': {
            'page': page,
            'limit': limit,
            'total': vehicleDirectory && emptyVehicles
                ? 0
                : search
                    ? 1
                    : 10000
          },
          'summary': {'count': 10000, 'assigned': 20000, 'deducted': 10000},
        };
      }
      // These two services return {action, message, vehicles, pagination}; the
      // response interceptor may wrap that result, but never renames its rows.
      final Map<String, dynamic> payload = vehicleDirectory
          ? {
              'action': true,
              'message': 'Vehicles fetched successfully',
              ...data
            }
          : {'action': true, 'data': data};
      h.resolve(Response(
          requestOptions: r,
          statusCode: 200,
          data: vehicleDirectory && directVehicleEnvelope
              ? payload
              : {'status': 'success', 'data': payload}));
    }));
    container = ProviderContainer(overrides: [
      workspaceDataScopeProvider.overrideWithValue('paging-owner'),
      authControllerProvider.overrideWith((ref) => auth),
      apiClientProvider
          .overrideWithValue(ApiClient(dio, activeUser: () => auth.state.user)),
      if (cache != null) localCacheProvider.overrideWithValue(cache),
    ]);
  }
  final String path;
  late final _Auth auth;
  late final Dio dio;
  late final ProviderContainer container;
  final requests = <RequestOptions>[];
  bool emptyVehicles = false;
  List<RequestOptions> get targetRequests =>
      requests.where((r) => r.uri.path == '/api$path').toList();
  Widget app(Widget child, {bool scroll = true}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: OpenVtsTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
              body: scroll ? SingleChildScrollView(child: child) : child)));

  Future<(ServerListPager<dynamic>, dynamic)> open() async {
    switch (path) {
      case '/superadmin/creditlogs/42':
      case '/superadmin/adminvehicles/42':
        final provider = superadminAdminDetailsControllerProvider('42');
        container.listen(provider, (_, __) {});
        final c = container.read(provider.notifier);
        if (path.contains('creditlogs')) {
          await c.loadCreditLogs();
          return (c.creditsPager!, c);
        }
        await c.loadVehicles();
        return (c.vehiclesPager!, c);
      case '/admin/linkvehicles/42':
        final provider = adminUserDetailsControllerProvider('42');
        container.listen(provider, (_, __) {});
        final c = container.read(provider.notifier);
        await c.loadVehicles();
        return (c.vehiclesPager!, c);
      case '/admin/vehicles':
        container.listen(adminVehiclesControllerProvider, (_, __) {});
        final c = container.read(adminVehiclesControllerProvider.notifier);
        return (c.pager!, c);
      case '/admin/drivers':
        container.listen(adminDriversControllerProvider, (_, __) {});
        final c = container.read(adminDriversControllerProvider.notifier);
        return (c.pager!, c);
      case '/admin/devices':
      case '/admin/simcards':
        container.listen(adminInventoryControllerProvider, (_, __) {});
        final c = container.read(adminInventoryControllerProvider.notifier);
        if (path.endsWith('/simcards')) {
          await c.selectTab(AdminInventoryTab.simCards);
          return (c.simsPager!, c);
        }
        return (c.devicesPager!, c);
      default:
        container.listen(userVehiclesControllerProvider, (_, __) {});
        final c = container.read(userVehiclesControllerProvider.notifier);
        return (c.pager!, c);
    }
  }

  void dispose() {
    container.dispose();
    dio.close(force: true);
  }
}

Map<String, dynamic> _row(int id) => {
      'id': id,
      'name': 'row $id',
      'vehicleName': 'row $id',
      'imei': '123456789$id',
      'simNumber': 'SIM-$id',
      'username': 'driver-$id',
      'status': 'IN_STOCK',
      'isActive': true,
      'createdAt': '2026-10-17T10:00:00Z',
      'vehicleType': {'name': 'Truck', 'slug': 'truck'},
      'credits': 10,
      'activity': 'ASSIGN',
      'balanceAfter': id == 9999 ? 719337 : 91338 - id,
    };

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(CurrentUser user) : super(AuthState.authenticated(user));
  void refresh() => state = AuthState.authenticated(
      state.user!.copyWith(access: const MobileAccess.account()));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
