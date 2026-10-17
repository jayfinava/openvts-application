import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:open_vts/core/access/mobile_access.dart';
import 'package:open_vts/core/access/workspace_scope_provider.dart';
import 'package:open_vts/core/api/api_client.dart';
import 'package:open_vts/core/providers/core_providers.dart';
import 'package:open_vts/core/theme/open_vts_theme.dart';
import 'package:open_vts/core/utils/date_time_formatter.dart';
import 'package:open_vts/features/auth/controllers/auth_controller.dart';
import 'package:open_vts/features/auth/controllers/auth_state.dart';
import 'package:open_vts/features/auth/models/current_user.dart';
import 'package:open_vts/features/superadmin/controllers/superadmin_admin_details_controller.dart';
import 'package:open_vts/features/superadmin/controllers/superadmin_providers.dart';
import 'package:open_vts/features/superadmin/models/superadmin_admin_details_model.dart';
import 'package:open_vts/features/superadmin/models/superadmin_vehicle_model.dart';
import 'package:open_vts/features/superadmin/screens/administrators/widgets/admin_details_documents_tab.dart';
import 'package:open_vts/features/superadmin/screens/dashboard/superadmin_dashboard_screen.dart';
import 'package:open_vts/features/superadmin/screens/vehicles/superadmin_vehicles_screen.dart';
import 'package:open_vts/features/superadmin/services/superadmin_admin_details_service.dart';
import 'package:open_vts/features/superadmin/services/superadmin_dashboard_service.dart';
import 'package:open_vts/features/superadmin/services/superadmin_payments_service.dart';
import 'package:open_vts/features/superadmin/services/superadmin_vehicle_service.dart';
import 'package:open_vts/features/user/models/user_settings_model.dart';
import 'package:open_vts/features/user/screens/settings/widgets/user_profile_header_card.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';

void main() {
  setUp(() => dotenv.testLoad(
      fileInput:
          'USE_MOCK_DATA=false\nAPI_BASE_URL=https://fleet.example/api'));

  testWidgets(
      'dashboard actor menu reads backend uid/Name and applies the selected ID',
      (tester) async {
    final requests = <RequestOptions>[];
    final api = _api((request) {
      requests.add(request);
      if (request.path.endsWith('/adminlist')) {
        return {
          'action': true,
          'data': [
            {'uid': 17, 'Name': 'Admin A'},
            {'uid': '18', 'Name': 'Admin B'},
          ]
        };
      }
      if (request.path.contains('activity')) {
        return {
          'action': true,
          'data': {'items': []}
        };
      }
      return {
        'action': true,
        'data': {'allAdmins': 2, 'totalVehicles': 5000}
      };
    });
    await _mount(tester, const SuperadminDashboardScreen(), overrides: [
      superadminDashboardServiceProvider
          .overrideWithValue(SuperadminDashboardService(api)),
    ]);
    await tester.pumpAndSettle();
    final filter = find.byIcon(Icons.filter_alt_outlined);
    await _reveal(tester, filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    expect(find.text('Admin A'), findsWidgets);
    expect(find.text('Admin B'), findsWidgets);
    await tester.tap(find.text('Admin B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply Filters'));
    await tester.pumpAndSettle();
    expect(requests.where((r) => r.queryParameters['actorId'] == 18),
        hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('vehicles request one batch per Next and debounce global search',
      (tester) async {
    final requests = <RequestOptions>[];
    final next = Completer<Map<String, dynamic>>();
    final api = _api((request) {
      requests.add(request);
      if (request.queryParameters['page'] == 2) return next.future;
      return _vehiclePage(request);
    });
    await _mount(tester, const SuperadminVehiclesScreen(), overrides: [
      superadminVehicleServiceProvider
          .overrideWithValue(SuperadminVehicleService(api)),
    ]);
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));
    expect(requests.single.queryParameters['limit'], 10);
    expect(find.text('Vehicle 1'), findsOneWidget);
    await _reveal(tester, find.byIcon(Icons.chevron_right_rounded));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    expect(requests, hasLength(2));
    expect(requests.last.queryParameters['page'], 2);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    next.complete(_vehiclePage(requests.last));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle 11'), findsOneWidget);
    final search = find.byType(TextField);
    await tester.enterText(search, 'need');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(search, 'needle');
    await tester.pump(const Duration(milliseconds: 349));
    expect(requests, hasLength(2));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(requests, hasLength(3));
    expect(requests.last.queryParameters['page'], 1);
    expect(requests.last.queryParameters['search'], 'needle');
    expect(find.text('Vehicle 4999'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
      'confirmed upload stays visible when the following list is stale and rejects duplicate submit',
      () async {
    final mutation = Completer<Map<String, dynamic>>();
    var posts = 0;
    final api = _api((request) {
      if (request.method == 'POST') {
        posts++;
        final form = request.data as FormData;
        expect(Map.fromEntries(form.fields)['associateId'], '7');
        expect(form.files.single.key, 'File');
        return mutation.future;
      }
      expect(request.queryParameters['rk'], isNotNull);
      return {'action': true, 'data': []};
    });
    final controller = _documents(api);
    addTearDown(controller.dispose);
    await controller.loadDocuments();
    final upload = controller.uploadDocument(_request());
    expect(await controller.uploadDocument(_request()), isFalse);
    await Future<void>.delayed(Duration.zero);
    mutation.complete({'action': true, 'data': _document});
    expect(await upload, isTrue);
    expect(posts, 1);
    expect(controller.state.documents.single.id, _document['id']);
    expect(controller.state.isUploadingDocument, isFalse);
  });

  testWidgets(
      'failed next batch retains rows and retries only the requested page',
      (tester) async {
    final requests = <RequestOptions>[];
    var fail = true;
    final api = _api((request) {
      requests.add(request);
      if (request.queryParameters['page'] == 2 && fail) {
        return {'action': false, 'message': 'private backend diagnostic'};
      }
      return _vehiclePage(request);
    });
    await _mount(tester, const SuperadminVehiclesScreen(), overrides: [
      superadminVehicleServiceProvider
          .overrideWithValue(SuperadminVehicleService(api)),
    ]);
    await tester.pumpAndSettle();
    await _reveal(tester, find.byIcon(Icons.chevron_right_rounded));
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('private backend'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(requests, hasLength(2));
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(requests.map((r) => r.queryParameters['page']), [1, 2, 2]);
    expect(find.text('Vehicle 11'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'new search retires an old pending batch and ignores its late result',
      (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    RequestOptions? old;
    final api = _api((request) {
      if (request.queryParameters['search'] == 'old') {
        old = request;
        return pending.future;
      }
      return _vehiclePage(request);
    });
    await _mount(tester, const SuperadminVehiclesScreen(), overrides: [
      superadminVehicleServiceProvider
          .overrideWithValue(SuperadminVehicleService(api)),
    ]);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'needle');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(old!.cancelToken!.isCancelled, isTrue);
    pending.complete(_vehiclePage(old!)
      ..['vehicles'] = [
        {'id': 2, 'name': 'Outdated result', 'isActive': true}
      ]);
    await tester.pumpAndSettle();
    expect(find.text('Vehicle 4999'), findsOneWidget);
    expect(find.text('Outdated result'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test(
      'server query uses supported global filters/sort and pagination metadata',
      () async {
    final api = _api((request) {
      expect(request.queryParameters['page'], 3);
      expect(request.queryParameters['limit'], 25);
      expect(request.queryParameters['search'], 'bus');
      expect(request.queryParameters['sortBy'], 'name');
      expect(request.queryParameters['sortDir'], 'asc');
      expect(jsonDecode(request.queryParameters['filters'] as String),
          {'status': false});
      return {
        'action': true,
        'vehicles': List.generate(5, (i) => {'id': i + 51, 'name': 'Bus $i'}),
        'pagination': {'page': 3, 'limit': 25, 'total': 55, 'totalPages': 3}
      };
    });
    final page = await SuperadminVehicleService(api).getVehicles(
        query: const SuperadminVehicleQuery(
            page: 3,
            limit: 25,
            search: ' bus ',
            status: 'inactive',
            sortBy: 'name',
            sortDir: 'asc'));
    expect(page.items, hasLength(5));
    expect(page.totalCount, 55);
  });

  test(
      'document upload enforces the same 5MB limit as the web and backend before sending',
      () async {
    var requests = 0;
    final controller = _documents(_api((_) {
      requests++;
      return {};
    }));
    addTearDown(controller.dispose);
    final result = await controller.uploadDocument(_request(
        file: PlatformFile(
            name: 'large.png',
            size: 6 * 1024 * 1024,
            bytes: Uint8List.fromList([1]))));
    expect(result, isFalse);
    expect(requests, 0);
    expect(controller.state.documentMutationErrorMessage, isNotNull);
    expect(controller.state.isUploadingDocument, isFalse);
  });

  test('late list response cannot erase a newly uploaded document', () async {
    final stale = Completer<Map<String, dynamic>>();
    var reads = 0;
    final api = _api((request) {
      if (request.method == 'POST') return {'action': true, 'data': _document};
      return ++reads == 1
          ? stale.future
          : {
              'action': true,
              'data': [_document]
            };
    });
    final controller = _documents(api);
    addTearDown(controller.dispose);
    final first = controller.loadDocuments();
    await Future<void>.delayed(Duration.zero);
    expect(await controller.uploadDocument(_request()), isTrue);
    stale.complete({'action': true, 'data': []});
    await first;
    expect(controller.state.documents.single.title, 'Driving license');
  });

  test('closing the administrator while a document read is pending is safe',
      () async {
    final response = Completer<Map<String, dynamic>>();
    final controller = _documents(_api((_) => response.future));
    final request = controller.loadDocuments();
    controller.dispose();
    response.complete({
      'action': true,
      'data': [_document]
    });
    await request;
  });

  testWidgets(
      'uploaded image has an inline preview and opens in the existing document dialog',
      (tester) async {
    final controller = _documents(_api((_) => {
          'action': true,
          'data': [_document]
        }));
    await tester.runAsync(() => controller.loadDocuments());
    await _mount(
        tester,
        const Scaffold(
            body: SingleChildScrollView(
                child: AdminDetailsDocumentsTab(adminId: '7'))),
        overrides: [
          superadminAdminDetailsControllerProvider
              .overrideWith((ref, id) => controller),
        ]);
    await tester.pumpAndSettle();
    expect(find.text('Driving license'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(
        (tester.widget<Image>(find.byType(Image)).image as ResizeImage)
            .imageProvider,
        isA<NetworkImage>().having((image) => image.url, 'configured URL',
            'https://custom.example/proxy/api/uploads/docs/user/7/license.png'));
    await tester.tap(find.text('Driving license'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
        '${dark ? 'dark' : 'light'} transparent avatar has no image-sized decoration or crop',
        (tester) async {
      await _mount(
          tester,
          Scaffold(
              body: UserProfileHeaderCard(
            profile: UserSettingsProfile.fromDynamic({'name': 'Operator'}),
            profileImageUrl: null,
            localAvatarBytes: File('assets/brand/icon.png').readAsBytesSync(),
            isUploadingAvatar: false,
            onChangeAvatar: null,
            onEditProfile: null,
          )),
          dark: dark);
      await tester.pumpAndSettle();
      final image = find.byType(Image);
      expect(tester.widget<Image>(image).fit, BoxFit.contain);
      final decorations =
          find.ancestor(of: image, matching: find.byType(DecoratedBox));
      for (final element in decorations.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.width > 60 || size.height > 60, isTrue,
            reason:
                'Transparent avatar content must not receive a frame/background.');
      }
      expect(find.ancestor(of: image, matching: find.byType(ClipRRect)),
          findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}

const _document = {
  'id': '9007199254740993',
  'title': 'Driving license',
  'docTypeId': 2,
  'fileName': 'license.png',
  'fileType': 'image/png',
  'filePath': '/uploads/docs/user/7/license.png',
  'associateType': 'USER',
  'isVisible': true
};

SuperadminAdminDocumentRequest _request({PlatformFile? file}) =>
    SuperadminAdminDocumentRequest(
      title: 'Driving license',
      docTypeId: '2',
      associateId: '7',
      isVisible: true,
      tags: const ['license'],
      description: '',
      expiryAt: null,
      file: file ??
          PlatformFile(
              name: 'license.png',
              size: 3,
              bytes: Uint8List.fromList([1, 2, 3])),
    );

SuperadminAdminDetailsController _documents(ApiClient api) =>
    SuperadminAdminDetailsController(
      adminId: '7',
      detailsService: SuperadminAdminDetailsService(api),
      paymentsService: SuperadminPaymentsService(api),
      onAdminStatusChanged: null,
    );

ApiClient _api(FutureOr<dynamic> Function(RequestOptions) route) {
  final dio = Dio(BaseOptions(baseUrl: 'https://fleet.example/api'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (request, handler) async {
    try {
      final data = await route(request);
      handler.resolve(Response(
          requestOptions: request,
          statusCode: 200,
          data: {'status': 'success', 'data': data}));
    } catch (error) {
      handler.reject(DioException(requestOptions: request, error: error));
    }
  }));
  return ApiClient(dio);
}

Map<String, dynamic> _vehiclePage(RequestOptions request) {
  final page = request.queryParameters['page'] as int;
  final search = request.queryParameters['search'];
  return {
    'action': true,
    'vehicles': List.generate(
        search == null ? 10 : 1,
        (i) => {
              'id': search == null ? (page - 1) * 10 + i + 1 : 4999,
              'name':
                  'Vehicle ${search == null ? (page - 1) * 10 + i + 1 : 4999}',
              'isActive': true,
              'imei': '12345',
              'vehicleType': {'name': 'Car'},
            }),
    'pagination': {
      'page': page,
      'limit': 10,
      'total': search == null ? 5000 : 1,
      'totalPages': search == null ? 500 : 1
    }
  };
}

Future<void> _mount(WidgetTester tester, Widget screen,
    {List<Override> overrides = const [], bool dark = false}) async {
  final router =
      GoRouter(routes: [GoRoute(path: '/', builder: (_, __) => screen)]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
      overrides: [
        workspaceDataScopeProvider.overrideWithValue('test-superadmin'),
        apiBaseUrlProvider.overrideWith((ref) => _Server()),
        authControllerProvider.overrideWith((ref) => _Auth()),
        appDateFormatterProvider.overrideWithValue(const AppDateFormatter(
            datePattern: 'DD MMM YYYY', use24Hour: false)),
        ...overrides,
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? OpenVtsTheme.dark : OpenVtsTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      )));
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 25 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsOneWidget);
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth()
      : super(const AuthState.authenticated(CurrentUser(
            id: '1',
            name: 'Owner',
            email: '',
            role: UserRole.superadmin,
            access: MobileAccess.account())));
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Server extends StateNotifier<String> implements ApiBaseUrlController {
  _Server() : super('https://custom.example/proxy/api');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
