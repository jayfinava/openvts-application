import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/storage/local_cache.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/notifications/controllers/notification_center_controller.dart';
import 'package:open_vts/features/notifications/models/app_notification.dart';
import 'package:open_vts/features/notifications/models/notification_page.dart';
import 'package:open_vts/features/notifications/services/notification_service.dart';
import 'package:open_vts/features/user/controllers/user_providers.dart';
import 'package:open_vts/features/user/screens/notifications/user_notifications_screen.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));

  testWidgets(
      'Vehicle and User inboxes retain separate filters, cursors, reads and counts',
      (tester) async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app(const UserNotificationsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle 300'), findsOneWidget);
    expect(find.text('User 300'), findsNothing);
    expect(h.reads('/user/notifications/vehicle'), 1);
    expect(h.reads('/user/notifications'), 1);
    final badge = h.container.read(userNotificationUnreadBadgeProvider.future);
    await tester.pumpAndSettle();
    expect(await badge, 4);
    final vehicle =
        h.container.read(userVehicleNotificationCenterProvider.notifier);
    final older = vehicle.loadMore();
    await tester.pumpAndSettle();
    await older;
    expect(
        h.container
            .read(userVehicleNotificationCenterProvider)
            .items
            .map((e) => e.id),
        [300, 299, 149]);
    expect(
        h.requests.any((r) =>
            r.uri.path.endsWith('/vehicle') &&
            r.queryParameters['beforeId'] == '150'),
        true);
    final read = vehicle.markAsRead(300);
    await tester.pumpAndSettle();
    await read;
    expect(h.container.read(userNotificationCenterProvider).items.first.isRead,
        false);
    expect(h.requests.last.uri.path, '/user/notifications/vehicle/300/read');
    await tester.tap(find.text('User (1)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('User 300'), 180,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('User 300'), findsOneWidget);
    await tester.tap(find.text('Unread'));
    await tester.pumpAndSettle();
    expect(h.container.read(userNotificationCenterProvider).unreadOnly, true);
    expect(h.container.read(userVehicleNotificationCenterProvider).unreadOnly,
        false);
    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(
        h.requests.any((r) =>
            r.uri.path == '/user/notifications/read-all' &&
            r.method == 'PATCH'),
        true);
    expect(
        h.container.read(userVehicleNotificationCenterProvider).unreadCount, 2);
    await tester.tap(find.text('Vehicle (2)'));
    await tester.pumpAndSettle();
    expect(h.container.read(userVehicleNotificationCenterProvider).items,
        hasLength(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'one feed failure leaves the other accessible at 320px and 2x text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final h = await _Harness.create();
    h.failVehicle = true;
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app(const UserNotificationsScreen(), scale: 2));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('User (1)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('User 300'), 180,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('User 300'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('query changes ignore delayed reads and disposal prevents state writes',
      () async {
    final service = _DeferredService();
    final controller = NotificationCenterController(service);
    final old = controller.load();
    final newer = controller.setUnreadOnly(true);
    service.pages[1].complete(_page([2]));
    await newer;
    service.pages[0].complete(_page([1]));
    await old;
    expect(controller.state.items.single.id, 2);
    final closing = controller.refresh();
    controller.dispose();
    service.pages[2].complete(_page([3]));
    await closing;
  });

  test('restricted vehicle windows advance even when no rows are visible',
      () async {
    final service = _DeferredService();
    final controller = NotificationCenterController(service);
    addTearDown(controller.dispose);
    final first = controller.load();
    service.pages[0].complete(NotificationPage.fromDynamic(
        {'items': [], 'nextCursor': 150, 'unreadCount': 1},
        requestedLimit: 20, cursorIsContinuation: true));
    await first;
    expect(controller.state.hasMore, true);
    final next = controller.loadMore();
    service.pages[1].complete(_page([149]));
    await next;
    expect(controller.state.items.single.id, 149);
    expect(service.beforeIds, [null, 150]);
  });

  test('load-more failure retains data and is contained for scroll callbacks',
      () async {
    final service = _DeferredService();
    final controller = NotificationCenterController(service);
    addTearDown(controller.dispose);
    final first = controller.load();
    service.pages[0].complete(_page([200], next: 200));
    await first;
    final next = controller.loadMore();
    service.pages[1].completeError(Exception('Offline'));
    await next;
    expect(controller.state.items.single.id, 200);
    expect(controller.state.isLoadingMore, false);
    expect(controller.state.errorMessage, isNotNull);
  });

  test('a failed single read does not undo another successful read', () async {
    final service = _DeferredService();
    final controller = NotificationCenterController(service);
    addTearDown(controller.dispose);
    final first = controller.load();
    service.pages[0].complete(_page([2, 1]));
    await first;
    final a = controller.markAsRead(2);
    final b = controller.markAsRead(1);
    final expectedFailure = expectLater(a, throwsA(isA<Exception>()));
    service.reads[1]!.complete();
    await b;
    service.reads[2]!.completeError(Exception('Rejected'));
    await expectedFailure;
    expect(controller.state.items.firstWhere((e) => e.id == 1).isRead, true);
    expect(controller.state.items.firstWhere((e) => e.id == 2).isRead, false);
    expect(controller.state.unreadCount, 1);
  });

  test('a late older page cannot undo an individual read', () async {
    final service = _DeferredService();
    final controller = NotificationCenterController(service);
    addTearDown(controller.dispose);
    final first = controller.load();
    service.pages[0].complete(_page([200], next: 200));
    await first;
    final older = controller.loadMore();
    final read = controller.markAsRead(200);
    expect(controller.state.isLoadingMore, false);
    await controller.loadMore();
    expect(service.pages, hasLength(2));
    service.pages[1].complete(_page([199], next: 199));
    await older;
    service.reads[200]!.complete();
    await read;
    expect(controller.state.items.single.id, 200);
    expect(controller.state.items.single.isRead, true);
    expect(controller.state.unreadCount, 0);
    final retry = controller.loadMore();
    expect(service.beforeIds.last, 200);
    service.pages[2].complete(
        const NotificationPage(items: [], hasMore: false, unreadCount: 0));
    await retry;
  });

  for (final fail in [false, true]) {
    test('a late older page cannot undo mark-all (failure: $fail)', () async {
      final service = _DeferredService();
      final controller = NotificationCenterController(service);
      addTearDown(controller.dispose);
      final first = controller.load();
      service.pages[0].complete(_page([200], next: 200));
      await first;
      final older = controller.loadMore();
      final all = controller.markAllAsRead();
      final expected = fail ? expectLater(all, throwsA(isA<Exception>())) : all;
      service.pages[1].complete(_page([199], next: 199));
      await older;
      if (fail) {
        service.allRead!.completeError(Exception('Rejected'));
      } else {
        service.allRead!.complete();
      }
      await expected;
      expect(controller.state.items.single.id, 200);
      expect(controller.state.items.single.isRead, !fail);
      expect(controller.state.unreadCount, fail ? 1 : 0);
      expect(controller.state.isLoadingMore, false);
      expect(controller.state.nextBeforeId, 200);
    });
  }
}

NotificationPage _page(List<int> ids, {int? next}) => NotificationPage(items: [
      for (final id in ids)
        AppNotification(id: id, title: 'Alert', message: '', isRead: false)
    ], hasMore: next != null, nextBeforeId: next, unreadCount: ids.length);

class _DeferredService extends NotificationService {
  _DeferredService() : super(ApiClient(Dio()));
  final pages = <Completer<NotificationPage>>[];
  final beforeIds = <int?>[];
  final reads = <int, Completer<void>>{};
  Completer<void>? allRead;
  @override
  String get listEndpoint => '/notifications';
  @override
  String get readAllEndpoint => '/notifications/read-all';
  @override
  String notificationReadEndpoint(int id) => '/notifications/$id/read';
  @override
  String get roleLabel => 'User';
  @override
  Future<NotificationPage> getNotifications(
      {int limit = 20,
      int? beforeId,
      bool unreadOnly = false,
      String? category}) {
    final pending = Completer<NotificationPage>();
    pages.add(pending);
    beforeIds.add(beforeId);
    return pending.future;
  }

  @override
  Future<void> markAsRead(int id) => (reads[id] = Completer<void>()).future;
  @override
  Future<void> markAllAsRead() => (allRead = Completer<void>()).future;
}

class _Harness {
  static Future<_Harness> create() async {
    SharedPreferences.setMockInitialValues({});
    return _Harness(LocalCache(await SharedPreferences.getInstance()));
  }

  _Harness(LocalCache cache) {
    dio.interceptors.add(InterceptorsWrapper(onRequest: (r, handler) {
      requests.add(r);
      final vehicle = r.uri.path.contains('/vehicle');
      if (vehicle && failVehicle) {
        handler.resolve(Response(requestOptions: r, statusCode: 503, data: {}));
        return;
      }
      final read = vehicle ? vehicleRead : userRead;
      if (r.method == 'PATCH') {
        if (r.uri.path.endsWith('/read-all')) {
          read.addAll(vehicle ? [300, 299, 149] : [300]);
        } else {
          read.add(int.parse(r.uri.path.split('/').reversed.elementAt(1)));
        }
        handler.resolve(Response(
            requestOptions: r,
            statusCode: 200,
            data: {'action': true, 'data': {}}));
        return;
      }
      var ids = vehicle
          ? (r.queryParameters['beforeId'] == '150' ? [149] : [300, 299])
          : [300, 250];
      if (r.queryParameters['unreadOnly'] == 'true') {
        ids = ids.where((id) => !read.contains(id) && id != 250).toList();
      }
      final unread = (vehicle ? [300, 299, 149] : [300])
          .where((id) => !read.contains(id))
          .length;
      handler.resolve(Response(requestOptions: r, statusCode: 200, data: {
        'action': true,
        'data': {
          'items': [
            for (final id in ids)
              {
                'id': id,
                'title': '${vehicle ? 'Vehicle' : 'User'} $id',
                'message': 'Notification',
                'vehicleName': vehicle ? 'Truck' : null,
                'imei': vehicle ? '123456789012345' : null,
                'isRead': id == 250 || read.contains(id)
              }
          ],
          'nextCursor':
              vehicle && r.queryParameters['beforeId'] == null ? 150 : null,
          'unreadCount': unread,
        }
      }));
    }));
    container = ProviderContainer(overrides: [
      apiClientProvider
          .overrideWithValue(ApiClient(dio, activeUser: () => actor)),
      authControllerProvider.overrideWith((ref) => _Auth()),
      localCacheProvider.overrideWithValue(cache),
    ]);
  }
  final actor = const CurrentUser(
      id: '42',
      name: 'Owner',
      email: 'owner@example.com',
      role: UserRole.user,
      access: MobileAccess.account());
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  late final ProviderContainer container;
  final requests = <RequestOptions>[];
  final vehicleRead = <int>{}, userRead = <int>{};
  bool failVehicle = false;
  int reads(String path) =>
      requests.where((r) => r.method == 'GET' && r.uri.path == path).length;
  Widget app(Widget child, {double scale = 1}) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
          theme: OpenVtsTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: child));
  void dispose() {
    container.dispose();
    dio.close(force: true);
  }
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth()
      : super(const AuthState.authenticated(CurrentUser(
            id: '42',
            name: 'Owner',
            email: 'owner@example.com',
            role: UserRole.user,
            access: MobileAccess.account())));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
