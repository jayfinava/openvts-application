import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/access/workspace_scope_provider.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/notifications/mobile_push_controller.dart';
import 'package:open_vts/core/notifications/mobile_push_platform.dart';
import 'package:open_vts/core/notifications/mobile_push_state.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/features/admin/controllers/admin_driver_details_controller.dart';
import 'package:open_vts/features/admin/controllers/admin_drivers_controller.dart';
import 'package:open_vts/features/admin/controllers/admin_inventory_controller.dart';
import 'package:open_vts/features/admin/controllers/admin_providers.dart';
import 'package:open_vts/features/admin/controllers/admin_team_controller.dart';
import 'package:open_vts/features/admin/controllers/admin_user_details_controller.dart';
import 'package:open_vts/features/admin/models/admin_dashboard_model.dart';
import 'package:open_vts/features/admin/models/admin_driver_details_model.dart';
import 'package:open_vts/features/admin/models/admin_driver_details_state.dart';
import 'package:open_vts/features/admin/models/admin_inventory_model.dart';
import 'package:open_vts/features/admin/models/admin_settings_model.dart';
import 'package:open_vts/features/admin/models/admin_user_details_model.dart';
import 'package:open_vts/features/admin/models/admin_vehicle_model.dart';
import 'package:open_vts/features/admin/screens/dashboard/widgets/admin_growth_chart_card.dart';
import 'package:open_vts/features/admin/screens/drivers/widgets/admin_driver_create_sheet.dart';
import 'package:open_vts/features/admin/screens/drivers/widgets/admin_driver_documents_tab.dart';
import 'package:open_vts/features/admin/screens/inventory/widgets/admin_inventory_add_sheet.dart';
import 'package:open_vts/features/admin/screens/team/widgets/admin_create_team_sheet.dart';
import 'package:open_vts/features/admin/screens/users/widgets/admin_user_logs_tab.dart';
import 'package:open_vts/features/admin/screens/users/widgets/admin_user_payments_tab.dart';
import 'package:open_vts/features/admin/screens/users/widgets/admin_user_vehicles_tab.dart';
import 'package:open_vts/features/admin/screens/vehicles/widgets/admin_vehicle_commands_tab.dart';
import 'package:open_vts/features/admin/screens/vehicles/widgets/admin_vehicle_events_tab.dart';
import 'package:open_vts/features/admin/services/admin_drivers_service.dart';
import 'package:open_vts/features/admin/services/admin_inventory_service.dart';
import 'package:open_vts/features/admin/services/admin_settings_service.dart';
import 'package:open_vts/features/admin/services/admin_team_service.dart';
import 'package:open_vts/features/admin/services/admin_user_details_service.dart';
import 'package:open_vts/features/admin/services/admin_users_service.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/controllers/security_controller.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/auth/screens/security_screen.dart';
import 'package:open_vts/features/notifications/models/notification_center_state.dart';
import 'package:open_vts/features/notifications/widgets/notification_center_view.dart';
import 'package:open_vts/features/superadmin/controllers/superadmin_providers.dart';
import 'package:open_vts/features/superadmin/controllers/superadmin_settings_controller.dart';
import 'package:open_vts/features/superadmin/models/superadmin_settings_model.dart';
import 'package:open_vts/features/superadmin/models/superadmin_settings_state.dart';
import 'package:open_vts/features/superadmin/screens/settings/widgets/profile_settings_section.dart';
import 'package:open_vts/features/user/controllers/user_notification_settings_controller.dart';
import 'package:open_vts/features/user/controllers/user_providers.dart';
import 'package:open_vts/features/user/models/user_notification_settings_model.dart';
import 'package:open_vts/features/user/models/user_report_model.dart';
import 'package:open_vts/features/user/models/user_settings_model.dart';
import 'package:open_vts/features/user/screens/notification_settings/user_notification_settings_screen.dart';
import 'package:open_vts/features/user/screens/reports/user_report_workspace_screen.dart';
import 'package:open_vts/features/user/screens/reports/user_reports_catalog_screen.dart';
import 'package:open_vts/features/user/services/user_notification_settings_service.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/utils/api_file_url.dart';
import 'package:open_vts/shared/widgets/open_vts_bottom_sheet.dart';
import 'package:open_vts/shared/widgets/open_vts_button.dart';
import 'package:open_vts/shared/widgets/open_vts_text_field.dart';

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final bytes = font.readAsBytesSync();
      for (final family in ['Inter', 'Satoshi']) {
        await (FontLoader(family)
              ..addFont(Future.value(ByteData.sublistView(bytes))))
            .load();
      }
    }
  });
  setUp(() => dotenv.testLoad(
      fileInput:
          'USE_MOCK_DATA=false\nAPI_BASE_URL=https://fleet.example/api'));

  for (final size in [(320.0, 1.0), (360.0, 1.0), (700.0, 2.0)]) {
    testWidgets(
        'vehicle Events filters apply and clear at ${size.$1}px / ${size.$2} text',
        (tester) async {
      _phone(tester);
      tester.view.physicalSize = Size(size.$1, 800);
      List<String?>? filters;
      var clears = 0;
      await _mount(
          tester,
          SingleChildScrollView(
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: AdminVehicleEventsTab(
                    imei: '123456789012345',
                    events: const [],
                    nextCursor: null,
                    isLoading: false,
                    isLoadingMore: false,
                    onLoad: () async {},
                    onLoadMore: () async {},
                    onApplyFilters: ({from, to, source, severity}) async {
                      filters = [source, severity];
                    },
                    onClearFilters: () async {
                      clears++;
                    },
                  ))),
          scale: size.$2);
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await _reveal(tester, dropdowns.first);
      await tester.tap(dropdowns.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('SYSTEM').last);
      await tester.pumpAndSettle();
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('CRITICAL').last);
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Apply'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(filters, ['SYSTEM', 'CRITICAL']);
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(clears, 1);
      expect(
          tester
              .widgetList<DropdownButtonFormField<String>>(dropdowns)
              .map((w) => w.initialValue),
          ['', '']);
      expect(tester.takeException(), isNull);
    });
  }

  for (final url in [null, 'https://fleet.example/api/uploads/profile.png']) {
    testWidgets(
        'Superadmin avatar stays circular ${url == null ? 'before' : 'after'} upload',
        (tester) async {
      _phone(tester);
      final state = const SuperadminSettingsState.initial().copyWith(
        profile: SuperadminProfileSettings(name: 'Owner', profileUrl: url),
      );
      await _mount(tester,
          SingleChildScrollView(child: ProfileSettingsSection(state: state)),
          overrides: [
            apiBaseUrlProvider.overrideWith((ref) => _Server()),
            apiClientProvider.overrideWithValue(_api((r) => [])),
            superadminSettingsControllerProvider
                .overrideWith((ref) => _SuperSettings(state)),
          ]);
      final avatar = tester
          .widgetList<Container>(find.byType(Container))
          .singleWhere((widget) =>
              widget.constraints?.maxWidth == 56 &&
              widget.constraints?.maxHeight == 56 &&
              widget.decoration is BoxDecoration);
      final decoration = avatar.decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      if (url != null) {
        expect(decoration.image?.fit, BoxFit.cover);
        expect(decoration.color, isNull,
            reason: 'No opaque background is added to image alpha.');
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
        'notification controls share sizing and wrap in ${dark ? 'dark' : 'light'} theme',
        (tester) async {
      _phone(tester, scale: 2);
      var unread = false;
      var marked = 0;
      await _mount(
          tester,
          NotificationCenterView(
            state: const NotificationCenterState(
                items: [], unreadCount: 3, hasMore: false),
            onRefresh: () async {},
            onRetry: () async {},
            onLoadMore: () async {},
            onUnreadOnlyChanged: (v) => unread = v,
            onMarkAllAsRead: () async {
              marked++;
            },
            onMarkAsRead: (_) async {},
          ),
          dark: dark,
          scale: 2);
      for (final label in ['All', 'Unread', 'Mark all read']) {
        final control = find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first;
        expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      }
      await tester.tap(find.text('Unread'));
      expect(unread, isTrue);
      await tester.tap(find.text('Mark all read'));
      expect(marked, 1);
      expect(tester.takeException(), isNull);
    });
  }

  test('country and state catalogs read the deployed isoCode contract', () {
    final countries = UserCountryOption.listFromDynamic({
      'data': {
        'data': [
          {'name': 'India', 'isoCode': 'IN'}
        ]
      }
    });
    final states = UserStateOption.listFromDynamic({
      'data': [
        {'name': 'Maharashtra', 'isoCode': 'MH'}
      ]
    });
    expect(countries.single.value, 'IN');
    expect(countries.single.label, 'India');
    expect(states.single.value, 'MH');
  });

  test(
      'driver document URLs retain the active proxy prefix and reject unsupported URLs',
      () {
    expect(
        resolveApiFileUrl(
            'https://custom.example/proxy/api/', '/uploads/license.pdf'),
        'https://custom.example/proxy/api/uploads/license.pdf');
    expect(
        resolveApiFileUrl('https://custom.example/proxy/api',
            '/proxy/api/uploads/license.pdf'),
        'https://custom.example/proxy/api/uploads/license.pdf');
    expect(
        resolveApiFileUrl(
            'https://custom.example/api', 'https://cdn.example/file.png'),
        'https://cdn.example/file.png');
    expect(
        resolveApiFileUrl('https://custom.example/api', 'javascript:alert(1)'),
        isNull);
  });

  test(
      'profile upload uses its confirmed URL without a second GET that can time out',
      () async {
    final requests = <RequestOptions>[];
    final service = AdminSettingsService(_api((r) {
      requests.add(r);
      if (r.method == 'GET') {
        throw TimeoutException('refresh must not gate upload');
      }
      final form = r.data as FormData;
      expect(form.fields, contains(const MapEntry('type', 'PROFILE')));
      expect(form.files.single.key, 'file');
      expect(r.receiveTimeout, const Duration(seconds: 300));
      return {'url': '/uploads/users/7/profile.png', 'type': 'PROFILE'};
    }));
    final updated = await service.uploadProfilePhoto(
        bytes: [1, 2, 3],
        fileName: 'photo.png',
        currentProfile: const AdminProfileSettings(uid: 7, name: 'Admin'));
    expect(updated.profileUrl, '/uploads/users/7/profile.png');
    expect(updated.name, 'Admin');
    expect(requests, hasLength(1));
  });

  test(
      'device creation completes while its optional inventory refresh is still pending',
      () async {
    final refresh = Completer<dynamic>();
    final controller =
        AdminInventoryController(service: AdminInventoryService(_api((r) {
      if (r.method == 'GET') return refresh.future;
      return {
        'id': 44,
        'imei': '123456789',
        'status': 'IN_STOCK',
        'isActive': true
      };
    })));
    final created = await controller.createDevice(
        const AdminCreateDeviceRequest(imei: '123456789', deviceTypeId: 1));
    expect(created?.id, '44');
    expect(controller.state.isCreating, isFalse);
    expect(controller.state.devices.single.id, '44');
    refresh.complete([]);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
  });

  testWidgets(
      'assign drawer keeps multiple selections across search and retries only failures',
      (tester) async {
    final calls = <String>[];
    var failSecond = true;
    final service = AdminUserDetailsService(_api((r) {
      final id = (r.data as Map)['vehicleId'].toString();
      calls.add(id);
      if (id == '2' && failSecond) throw TimeoutException('temporary');
      return {'id': id};
    }));
    final controller =
        AdminUserDetailsController(userId: '7', service: service);
    // Load realistic linked/available responses without a profile request.
    final listService = _Assignments(service);
    final seeded =
        AdminUserDetailsController(userId: '7', service: listService);
    await seeded.loadVehicles();
    await _mount(tester,
        const SingleChildScrollView(child: AdminUserVehiclesTab(userId: '7')),
        overrides: [
          adminUserDetailsControllerProvider('7').overrideWith((ref) => seeded)
        ]);
    await _reveal(tester, find.text('Assign Vehicle'));
    await tester.tap(find.text('Assign Vehicle'));
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, 'Search available vehicles');
    await tester.tap(find.text('Truck one').last);
    await tester.pump();
    await tester.enterText(search, 'Truck two');
    await tester.pump();
    await tester.tap(find.text('Truck two').last);
    await tester.pump();
    expect(find.text('2 vehicles selected'), findsOneWidget);
    await tester.tap(find.text('Assign').last);
    await tester.pumpAndSettle();
    expect(calls.toSet(), {'1', '2'});
    expect(find.text('1 vehicle selected'), findsOneWidget);
    failSecond = false;
    await tester.tap(find.text('Assign').last);
    await tester.pumpAndSettle();
    expect(calls.where((id) => id == '1'), hasLength(1));
    expect(calls.where((id) => id == '2'), hasLength(2));
    expect(find.text('Assign'), findsNothing);
    expect(seeded.state.linkedVehicles, hasLength(2));
    controller.dispose();
    expect(tester.takeException(), isNull);
  });

  test(
      'renewal completes once confirmed even while payment and vehicle refreshes wait',
      () async {
    final pending = Completer<dynamic>();
    var writes = 0;
    final service = AdminUserDetailsService(_api((r) {
      if (r.method == 'GET') return pending.future;
      writes++;
      expect((r.data as Map)['vehicleIds'], [1]);
      expect((r.data as Map)['idempotencyKey'], isNotEmpty);
      expect(r.receiveTimeout, const Duration(seconds: 60));
      return {
        'transaction': {'id': '500', 'amount': '100', 'status': 'SUCCESS'}
      };
    }));
    final controller =
        AdminUserDetailsController(userId: '7', service: service);
    expect(
        await controller.renewVehiclesPayment(
            const AdminRenewVehiclesPaymentRequest(
                userId: '7', vehicleIds: ['1'], paymentMode: 'CASH')),
        isTrue);
    expect(writes, 1);
    expect(controller.state.isRenewingPayment, isFalse);
    expect(controller.state.payments.single.id, '500');
    pending.complete([]);
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
  });

  test('a late All logs response cannot overwrite a selected category',
      () async {
    final first = Completer<dynamic>();
    final queries = <Map<String, dynamic>>[];
    final service = AdminUserDetailsService(_api((r) {
      queries.add(r.queryParameters);
      if (queries.length == 1) return first.future;
      return {
        'items': [
          {'id': 2, 'action': 'USER.VEHICLE.UPDATE'}
        ],
        'hasMore': false
      };
    }));
    final controller =
        AdminUserDetailsController(userId: '7', service: service);
    final old = controller.loadLogs();
    await Future<void>.delayed(Duration.zero);
    controller.setLogFilters(actionPrefix: 'VEHICLE');
    await controller.loadLogs();
    first.complete({
      'items': [
        {'id': 1, 'action': 'AUTH.LOGIN'}
      ]
    });
    await old;
    expect(queries.last['q'], 'VEHICLE');
    expect(controller.state.logs.single.id, 2);
    controller.dispose();
  });

  testWidgets('All growth history renders on a narrow screen with large text',
      (tester) async {
    _phone(tester, scale: 1.5);
    final key = GlobalKey();
    await _mount(
        tester,
        SingleChildScrollView(
            child: RepaintBoundary(
                key: key,
                child: AdminGrowthChartCard(
                    points: List.generate(
                        48,
                        (i) => AdminMonthGraphPoint(
                            month: [
                              'Jan',
                              'Feb',
                              'Mar',
                              'Apr',
                              'May',
                              'Jun',
                              'Jul',
                              'Aug',
                              'Sep',
                              'Oct',
                              'Nov',
                              'Dec'
                            ][i % 12],
                            year: 2023 + i ~/ 12,
                            userCount: i + 4,
                            vehicleCount: i * 2 + 2))))),
        scale: 1.5);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image = await (key.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      File('build/admin-growth-all.png')
          .writeAsBytesSync(data!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('report catalog and direct workspace honor report permissions',
      (tester) async {
    final auth = _Auth(_user(reports: {'distance': true, 'alerts': true}));
    await _mount(tester, const UserReportsCatalogScreen(), auth: auth);
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Overspeed'), findsNothing);
    expect(find.text('Device Logs'), findsNothing);
    for (final key
        in UserReportKey.values.where((key) => key != UserReportKey.distance)) {
      await _mount(tester, UserReportWorkspaceScreen(reportKey: key),
          auth: _Auth(_user(reports: {'distance': true})),
          overrides: [
            userReportControllerProvider.overrideWith((ref) =>
                throw StateError('Denied report must not initialize APIs'))
          ]);
      expect(find.text('This report is not available for your account.'),
          findsOneWidget);
    }
    await _mount(tester, const UserReportsCatalogScreen(),
        auth: _Auth(_user()));
    expect(find.text('This report is not available for your account.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'notification vehicle search hides rows without dropping other drafts',
      (tester) async {
    final service = _NotificationSettings();
    final controller = UserNotificationSettingsController(service: service);
    await controller.load();
    await _mount(tester, const UserNotificationSettingsScreen(),
        auth: _Auth(_user(), demo: true),
        overrides: [
          userNotificationSettingsControllerProvider
              .overrideWith((ref) => controller),
          mobilePushControllerProvider.overrideWith((ref) => _Push()),
        ]);
    await _reveal(
        tester, find.byKey(const ValueKey('notification-vehicle-search')));
    await tester.enterText(
        find.byKey(const ValueKey('notification-vehicle-search')), 'AB-22');
    await tester.pumpAndSettle();
    controller.updateBasicToggle(2, ignitionEnabled: true);
    await tester.pump();
    expect(find.text('Truck one'), findsNothing);
    expect(find.text('Truck two'), findsOneWidget);
    expect(controller.state.draftPreferences!.vehicles, hasLength(2));
    expect(
        controller.state.draftPreferences!.basic
            .firstWhere((r) => r.vehicleId == 2)
            .ignitionEnabled,
        isTrue);
    expect(
        controller.state.draftPreferences!.basic
            .firstWhere((r) => r.vehicleId == 1)
            .alarmEnabled,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  test(
      'multi-assignment deduplicates IDs and limits concurrent mutations to three',
      () async {
    var active = 0;
    var maximum = 0;
    final calls = <String>[];
    final service = AdminUserDetailsService(_api((r) async {
      final id = (r.data as Map)['vehicleId'].toString();
      calls.add(id);
      active++;
      if (active > maximum) maximum = active;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      active--;
      if (id == '2') throw TimeoutException('temporary');
      return {'id': id};
    }));
    final result = await service
        .linkVehicles('7', ['1', '1', '2', '3', '4', '5', '6', '7', '8']);
    expect(maximum, 3);
    expect(calls, hasLength(8));
    expect(result.assignedIds, hasLength(7));
    expect(result.failedIds, {'2'});
  });

  testWidgets(
      'user renewal shows validation inside the drawer and closes after confirmed payment',
      (tester) async {
    var writes = 0;
    final controller = AdminUserDetailsController(
        userId: '7',
        service: AdminUserDetailsService(_api((r) {
          if (r.method == 'POST') {
            writes++;
            return {
              'transaction': {'id': 500, 'amount': '100', 'status': 'SUCCESS'}
            };
          }
          if (r.path.contains('/unlinkvehicles')) return [];
          if (r.path.contains('/linkvehicles')) {
            return [
              {
                'id': 1,
                'name': 'Truck one',
                'plan': {'id': 1, 'name': 'Basic', 'price': 100}
              }
            ];
          }
          return {'items': [], 'total': 0};
        })));
    await tester.runAsync(() => controller.loadVehicles());
    await _mount(tester,
        const SingleChildScrollView(child: AdminUserPaymentsTab(userId: '7')),
        overrides: [
          adminUserDetailsControllerProvider('7')
              .overrideWith((ref) => controller)
        ]);
    await tester.tap(find.widgetWithText(OpenVtsButton, 'Renew Vehicle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew').last);
    await tester.pumpAndSettle();
    expect(find.text('Select at least one vehicle.'), findsWidgets);
    expect(writes, 0);
    await _reveal(tester, find.text('Truck one'),
        scrollable: find.byType(ListView).last);
    await tester.tap(find.text('Truck one').last);
    await tester.pump();
    await tester.drag(find.byType(ListView).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    final amount = find.descendant(
        of: find.widgetWithText(OpenVtsTextField, 'Amount override'),
        matching: find.byType(TextField));
    await tester.enterText(amount, '100');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renew').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter an override reason of 5–500 characters.'),
        findsWidgets);
    expect(writes, 0);
    final reason = find.descendant(
        of: find.widgetWithText(
            OpenVtsTextField, 'Reason for amount override (5–500 characters)'),
        matching: find.byType(TextField));
    await tester.enterText(reason, 'Annual cash renewal');
    await tester.pump();
    await tester.tap(find.text('Renew').last);
    await tester.pumpAndSettle();
    expect(writes, 1);
    expect(find.text('Renew'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'inline device form closes and returns the created device before inventory refresh',
      (tester) async {
    final refresh = Completer<dynamic>();
    AdminInventoryDevice? returned;
    final controller =
        AdminInventoryController(service: AdminInventoryService(_api((r) {
      if (r.method == 'POST') {
        return {
          'id': 44,
          'imei': '123456789',
          'status': 'IN_STOCK',
          'isActive': true
        };
      }
      if (r.path.contains('devicestypes')) {
        return [
          {'id': 1, 'name': 'Tracker One'}
        ];
      }
      if (r.path.endsWith('/devices')) return refresh.future;
      return [];
    })));
    await _mount(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () async {
                  returned =
                      await OpenVtsBottomSheet.show<AdminInventoryDevice>(
                          context: context,
                          title: 'Add Device',
                          initialChildSize: .8,
                          minChildSize: .6,
                          maxChildSize: .9,
                          child:
                              const AdminInventoryAddSheet(deviceOnly: true));
                },
                child: const Text('New device'))),
        overrides: [
          adminInventoryControllerProvider.overrideWith((ref) => controller)
        ]);
    await tester.tap(find.text('New device'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456789');
    await tester.tap(find.text('Select device type'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracker One').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(returned?.id, '44');
    expect(find.byType(AdminInventoryAddSheet), findsNothing);
    refresh.complete([]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final driver in [false, true]) {
    testWidgets(
        '${driver ? 'Driver' : 'Team'} form remains usable above keyboard',
        (tester) async {
      _phone(tester);
      final api = _api((r) => []);
      final driverController =
          AdminDriversController(service: AdminDriversService(api));
      final teamController =
          AdminTeamController(service: AdminTeamService(api));
      await _mount(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () {
                    if (driver) {
                      showDriverCreateSheet(
                          context: context,
                          provider: adminDriversControllerProvider);
                    } else {
                      OpenVtsBottomSheet.show<void>(
                          context: context,
                          title: 'Add Team',
                          initialChildSize: .9,
                          minChildSize: .5,
                          maxChildSize: .96,
                          child:
                              const AdminCreateTeamSheet(isSubmitting: false));
                    }
                  },
                  child: const Text('Open form'))),
          overrides: [
            adminDriversControllerProvider
                .overrideWith((ref) => driverController),
            adminTeamControllerProvider.overrideWith((ref) => teamController),
            adminUsersServiceProvider.overrideWithValue(AdminUsersService(api)),
          ]);
      await tester.tap(find.text('Open form'));
      await tester.pumpAndSettle();
      final field = find.byType(TextField).first;
      await tester.tap(field);
      await tester.enterText(field, 'Example name');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final save = find.text(driver ? 'Create driver' : 'Save').last;
      expect(save.hitTestable(), findsOneWidget);
      expect(tester.getRect(save).bottom, lessThan(440));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('all user log chips send their backend contains filter',
      (tester) async {
    final queries = <String?>[];
    final controller = AdminUserDetailsController(
        userId: '7',
        service: AdminUserDetailsService(_api((r) {
          queries.add(r.queryParameters['q'] as String?);
          return {'items': [], 'hasMore': false};
        })));
    await _mount(tester,
        const SingleChildScrollView(child: AdminUserLogsTab(userId: '7')),
        overrides: [
          adminUserDetailsControllerProvider('7')
              .overrideWith((ref) => controller)
        ]);
    for (final label in [
      'Security',
      'Settings',
      'Billing',
      'Vehicles',
      'Drivers',
      'All'
    ]) {
      await _reveal(tester, find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(queries, ['AUTH', 'SETTINGS', 'PAYMENT', 'VEHICLE', 'DRIVER', null]);
    final search = find.byType(TextField).first;
    await tester.enterText(search, 'manual text');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehicles'));
    await tester.pumpAndSettle();
    expect(queries.last, 'VEHICLE');
    expect(tester.widget<TextField>(search).controller!.text, isEmpty);
    await tester.enterText(search, 'another search');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(queries.last, 'another search');
    expect(controller.state.logActionPrefix, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long vehicle command template fits narrow content and selection',
      (tester) async {
    _phone(tester);
    await _mount(
        tester,
        SingleChildScrollView(
            child: AdminVehicleCommandsTab(
          vehicle: AdminVehicleDetails.fromJson(
              {'id': 7, 'name': 'Truck', 'imei': '123456789'}),
          customCommands: const [
            AdminCustomCommand(
                id: '1',
                command: 'STATUS#',
                isActive: true,
                commandTypeName:
                    'A very long command template description for an enterprise device')
          ],
          systemVariables: const [],
          history: const [],
          isLoading: false,
          isSending: false,
          onRefresh: () async {},
          onSend: ({required command, note, commandId}) async {},
          onPollStatus: (_) async => null,
          onFetchCommandLog: (_) async => null,
        )));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('A very long').last);
    await tester.pumpAndSettle();
    expect(find.text('STATUS#'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'driver image document opens within the app using the active server',
      (tester) async {
    final controller = AdminDriverDetailsController(
        driverId: '7', service: AdminDriversService(_api((r) => [])));
    final provider = StateNotifierProvider.autoDispose<
        AdminDriverDetailsController,
        AdminDriverDetailsState>((ref) => controller);
    final state = controller.state.copyWith(documents: [
      AdminDriverDocument.fromJson({
        'id': 1,
        'title': 'License image',
        'fileName': 'license.png',
        'fileType': 'image/png',
        'filePath': '/uploads/docs/driver/7/license.png'
      })
    ]);
    await _mount(
        tester,
        SingleChildScrollView(
            child: AdminDriverDocumentsTab(provider: provider, state: state)),
        overrides: [apiBaseUrlProvider.overrideWith((ref) => _Server())]);
    await tester.tap(find.byTooltip('Document actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View/Download'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    final resized = image.image as ResizeImage;
    expect((resized.imageProvider as NetworkImage).url,
        'https://custom.example/proxy/api/uploads/docs/driver/7/license.png');
    expect(image.color, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'create API token dialog keeps fields separate and scrolls above keyboard',
      (tester) async {
    _phone(tester);
    await _mount(tester, const SecurityScreen(),
        auth: _Auth(_user()),
        scale: 1.5,
        overrides: [
          securityControllerProvider.overrideWith((ref) => _Security())
        ]);
    await _reveal(tester, find.text('Create API token'));
    await tester.tap(find.text('Create API token'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    final fields = find.descendant(
        of: find.byType(Dialog), matching: find.byType(TextFormField));
    final rects = fields
        .evaluate()
        .map((e) => tester.getRect(find.byWidget(e.widget)))
        .toList();
    for (var i = 1; i < rects.length; i++) {
      expect(rects[i].top, greaterThanOrEqualTo(rects[i - 1].bottom));
    }
    expect(find.text('Token name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ApiClient _api(FutureOr<dynamic> Function(RequestOptions) route) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fleet.example/api'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (r, h) async {
    try {
      h.resolve(Response(requestOptions: r, statusCode: 200, data: {
        'status': 'success',
        'data': {'action': true, 'data': await route(r)}
      }));
    } catch (e) {
      h.reject(DioException(requestOptions: r, error: e));
    }
  }));
  return ApiClient(dio);
}

CurrentUser _user({Map<String, bool> reports = const {}}) => CurrentUser(
    id: '1',
    name: 'User',
    email: '',
    role: UserRole.user,
    access: MobileAccess(
        loaded: true, features: const {'reports': true}, reports: reports));

Future<void> _mount(WidgetTester tester, Widget screen,
    {List<Override> overrides = const [],
    _Auth? auth,
    bool dark = false,
    double scale = 1}) async {
  await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        workspaceDataScopeProvider.overrideWithValue('ux-test'),
        authControllerProvider.overrideWith((ref) =>
            auth ??
            _Auth(const CurrentUser(
                id: '1',
                name: 'Admin',
                email: '',
                role: UserRole.admin,
                access: MobileAccess.account()))),
        ...overrides
      ],
      child: MaterialApp(
          theme: dark ? OpenVtsTheme.dark : OpenVtsTheme.light,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: Scaffold(body: screen))));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {double scale = 1}) {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _reveal(WidgetTester tester, Finder target,
    {Finder? scrollable}) async {
  for (var i = 0; i < 25 && target.hitTestable().evaluate().isEmpty; i++) {
    final scroll = scrollable ?? find.byType(Scrollable).first;
    await tester.drag(scroll, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

class _SuperSettings extends StateNotifier<SuperadminSettingsState>
    implements SuperadminSettingsController {
  _SuperSettings(super.state);
  @override
  Future<void> loadEmailSubscription() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth(CurrentUser user, {bool demo = false})
      : super(AuthState.authenticated(user, isDemo: demo));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Server extends StateNotifier<String> implements ApiBaseUrlController {
  _Server() : super('https://custom.example/proxy/api');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Assignments extends Fake implements AdminUserDetailsService {
  _Assignments(this.service);
  final AdminUserDetailsService service;
  @override
  Future<List<AdminUserVehicle>> getLinkedVehicles(String id) async => [];
  @override
  Future<List<AdminUserVehicle>> getUnlinkedVehicles(String id) async => [
        AdminUserVehicle.fromJson(
            {'id': 1, 'name': 'Truck one', 'plateNumber': 'AB-11'}),
        AdminUserVehicle.fromJson(
            {'id': 2, 'name': 'Truck two', 'plateNumber': 'AB-22'})
      ];
  @override
  Future<AdminVehicleAssignmentResult> linkVehicles(
          String id, Iterable<String> ids) =>
      service.linkVehicles(id, ids);
}

class _NotificationSettings extends Fake
    implements UserNotificationSettingsService {
  @override
  Future<UserNotificationPreferences> fetchPreferences(
          {String? refreshKey}) async =>
      UserNotificationPreferences.fromDynamic({
        'vehicles': [
          {'id': 1, 'name': 'Truck one', 'plateNumber': 'AB-11'},
          {'id': 2, 'name': 'Truck two', 'plateNumber': 'AB-22'}
        ],
        'basic': [
          {'vehicleId': 1, 'alarmEnabled': true},
          {'vehicleId': 2}
        ]
      });
}

class _Push extends StateNotifier<MobilePushState>
    implements MobilePushController {
  _Push()
      : super(MobilePushState.initial(
            isSupported: false, platform: MobilePushPlatform.unsupported));
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Security extends StateNotifier<SecurityState>
    implements SecurityController {
  _Security()
      : super(const SecurityState(
            status: {'enabled': true, 'devices': []}, tokens: {'items': []}));
  @override
  Future<void> load() async {}
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
