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
import 'package:open_vts/features/user/controllers/user_drivers_controller.dart';
import 'package:open_vts/features/user/controllers/user_providers.dart';
import 'package:open_vts/features/user/controllers/user_subusers_controller.dart';
import 'package:open_vts/features/user/models/user_driver_model.dart';
import 'package:open_vts/features/user/models/user_settings_model.dart';
import 'package:open_vts/features/user/models/user_subuser_model.dart';
import 'package:open_vts/features/user/screens/accounts/drivers/widgets/user_driver_create_sheet.dart';
import 'package:open_vts/features/user/screens/accounts/subusers/widgets/user_subuser_create_sheet.dart';
import 'package:open_vts/features/user/services/user_driver_service.dart';
import 'package:open_vts/features/user/services/user_settings_service.dart';
import 'package:open_vts/features/user/services/user_subuser_service.dart';
import 'package:open_vts/l10n/app_localizations.dart';
import 'package:open_vts/shared/models/user_role.dart';
import 'package:open_vts/shared/widgets/open_vts_button.dart';
import 'package:open_vts/shared/widgets/open_vts_searchable_dropdown.dart';
import 'package:open_vts/shared/widgets/open_vts_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => dotenv.testLoad(fileInput: 'USE_MOCK_DATA=false'));

  testWidgets(
      'Subuser matches optional fields and phone-pair validation with API prefixes',
      (tester) async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    await h.open(tester);
    await _enter(tester, 'Name', 'e\u0301');
    await _enter(tester, 'Mobile (optional)', '1234567');
    await _enter(tester, 'Password', ' pass ');
    await _submit(tester, 'Create Sub User');
    expect(h.requests, isEmpty);
    expect(find.text('Mobile prefix is required'), findsOneWidget);
    await _choose(tester, 'Prefix', '+971');
    await _submit(tester, 'Create Sub User');
    expect(h.requests, hasLength(1));
    final payload = (h.requests.single as CreateUserSubUserRequest).toJson();
    expect(payload, {
      'name': 'é',
      'mobilePrefix': '+971',
      'mobileNumber': '1234567',
      'password': ' pass ',
      'isActive': true
    });
    expect(h.references.prefixReads, 1);
    expect(h.references.driverListReads, 0);
  });

  testWidgets(
      'Subuser prevents duplicate submission and closes after confirmed success',
      (tester) async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    final response = Completer<UserSubUser?>();
    h.submission = (_) => response.future;
    await h.open(tester);
    await _enter(tester, 'Name', 'A');
    await _enter(tester, 'Email (optional)', ' User@Example.COM ');
    await _enter(tester, 'Password', '      ');
    await _submit(tester, 'Create Sub User', settle: false);
    final buttons =
        tester.widgetList<OpenVtsButton>(find.byType(OpenVtsButton)).toList();
    expect(buttons.where((b) => b.label == 'Create Sub User').single.onPressed,
        isNull);
    expect(h.requests, hasLength(1));
    expect((h.requests.single as CreateUserSubUserRequest).toJson()['email'],
        'user@example.com');
    response.complete(UserSubUser.fromJson({'id': 7, 'name': 'A'}));
    await tester.pumpAndSettle();
    expect(find.byType(UserSubUserCreateSheet), findsNothing);
    expect(h.result, isA<UserSubUser>());
  });

  testWidgets(
      'Driver uses owner country, international postal input and exact payload names',
      (tester) async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    await h.open(tester, driver: true);
    await _enter(tester, 'Name', '李');
    await _enter(tester, 'Username', 'driver.42');
    await _enter(tester, 'Email (optional)', 'Driver@Example.COM');
    await _enter(tester, 'Mobile', '(123) 4567');
    await _enter(tester, 'Password', ' pass ');
    await _enter(tester, 'Address (optional)', '  1 Main St  ');
    await _enter(tester, 'Pincode (optional)', 'K1A 0B1');
    final postal =
        tester.widget<OpenVtsTextField>(_field('Pincode (optional)'));
    expect(postal.keyboardType, TextInputType.text);
    expect(postal.maxLength, 20);
    await _submit(tester, 'Create Driver');
    final payload = (h.requests.single as CreateUserDriverRequest).toJson();
    expect(payload, {
      'name': '李',
      'username': 'driver.42',
      'email': 'driver@example.com',
      'mobilePrefix': '+91',
      'mobile': '1234567',
      'password': ' pass ',
      'countryCode': 'GB',
      'address': '1 Main St',
      'pincode': 'K1A 0B1'
    });
    expect(h.references.stateCalls, ['GB']);
  });

  testWidgets(
      'a manual country selection wins over a late profile; stale state replies are discarded',
      (tester) async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    final profile = Completer<UserSettingsProfile>();
    h.profile.response = profile.future;
    final old = Completer<List<UserDriverStateOption>>();
    h.references.stateRequest = (country) => country == 'IN'
        ? old.future
        : Future.value(
            const [UserDriverStateOption(value: 'ENG', label: 'England')]);
    await h.open(tester, driver: true);
    await _choose(tester, 'Country', 'IN', settle: false);
    await _choose(tester, 'Country', 'GB');
    profile.complete(const UserSettingsProfile(
        uid: 42, address: UserSettingsAddress(countryCode: 'IN')));
    old.complete(
        const [UserDriverStateOption(value: 'MH', label: 'Maharashtra')]);
    await tester.pumpAndSettle();
    await _show(tester, _dropdown('Country'));
    expect(
        tester
            .widget<OpenVtsSearchableDropdown<String>>(_dropdown('Country'))
            .value,
        'GB');
    await _show(tester, _dropdown('State (optional)'));
    final state = tester.widget<OpenVtsSearchableDropdown<String>>(
        _dropdown('State (optional)'));
    expect(state.options.any((o) => o.value == 'ENG'), true);
    expect(state.options.any((o) => o.value == 'MH'), false);
  });

  testWidgets('another account profile cannot default the Driver country',
      (tester) async {
    final h = await _Harness.create();
    addTearDown(h.dispose);
    h.profile.response = Future.value(const UserSettingsProfile(
        uid: 99, address: UserSettingsAddress(countryCode: 'IN')));
    await h.open(tester, driver: true);
    await _show(tester, _dropdown('Country'));
    expect(
        tester
            .widget<OpenVtsSearchableDropdown<String>>(_dropdown('Country'))
            .value,
        isNull);
  });

  for (final driver in [false, true]) {
    testWidgets(
        '${driver ? 'Driver' : 'Subuser'} validates required fields above the scrolled submit button',
        (tester) async {
      final h = await _Harness.create();
      addTearDown(h.dispose);
      await h.open(tester, driver: driver);
      await _submit(tester, driver ? 'Create Driver' : 'Create Sub User');
      expect(h.requests, isEmpty);
      expect(find.text('Name is required'), findsOneWidget);
      expect(
          find.text('Password must be at least 6 characters'), findsOneWidget);
    });
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          '${driver ? 'Driver' : 'Subuser'} form scrolls with 320px, keyboard and ${scale}x text',
          (tester) async {
        final h = await _Harness.create();
        addTearDown(h.dispose);
        await h.open(tester,
            driver: driver, width: 320, scale: scale, keyboard: 300);
        await _enter(tester, 'Name', 'A');
        await _enter(tester, 'Password', '123456');
        await _show(
            tester,
            find.widgetWithText(
                OpenVtsButton, driver ? 'Create Driver' : 'Create Sub User'));
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Finder _field(String label) =>
    find.byWidgetPredicate((w) => w is OpenVtsTextField && w.label == label);
Finder _dropdown(String label) => find.byWidgetPredicate(
    (w) => w is OpenVtsSearchableDropdown<String> && w.label == label);
Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find
          .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
          .last);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await _show(tester, _field(label));
  await tester.enterText(
      find.descendant(of: _field(label), matching: find.byType(TextFormField)),
      text);
  await tester.pumpAndSettle();
}

Future<void> _choose(WidgetTester tester, String label, String value,
    {bool settle = true}) async {
  await _show(tester, _dropdown(label));
  tester
      .widget<OpenVtsSearchableDropdown<String>>(_dropdown(label))
      .onChanged(value);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Future<void> _submit(WidgetTester tester, String label,
    {bool settle = true}) async {
  final finder = find.widgetWithText(OpenVtsButton, label);
  await _show(tester, finder);
  await tester.tap(finder);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

class _References extends UserDriverService {
  _References() : super(ApiClient(Dio()));
  int prefixReads = 0, driverListReads = 0;
  final stateCalls = <String>[];
  Future<List<UserDriverStateOption>> Function(String)? stateRequest;
  @override
  Future<List<UserDriver>> fetchDrivers({String? refreshKey}) async {
    driverListReads++;
    return [];
  }

  @override
  Future<List<UserDriverMobilePrefixOption>> fetchMobilePrefixes() async {
    prefixReads++;
    return const [
      UserDriverMobilePrefixOption(
          value: '+971', label: 'United Arab Emirates', countryCode: 'AE'),
      UserDriverMobilePrefixOption(
          value: '+91', label: 'India', countryCode: 'IN')
    ];
  }

  @override
  Future<List<UserDriverCountryOption>> fetchCountries() async => const [
        UserDriverCountryOption(value: 'GB', label: 'United Kingdom'),
        UserDriverCountryOption(value: 'IN', label: 'India')
      ];
  @override
  Future<List<UserDriverStateOption>> fetchStates(String countryCode) async {
    stateCalls.add(countryCode);
    return stateRequest?.call(countryCode) ?? Future.value(const []);
  }

  @override
  Future<List<UserDriverCityOption>> fetchCities(
          String countryCode, String stateCode) async =>
      [];
}

class _Profile extends UserSettingsService {
  _Profile() : super(ApiClient(Dio()));
  Future<UserSettingsProfile> response = Future.value(const UserSettingsProfile(
      uid: 42, address: UserSettingsAddress(countryCode: 'GB')));
  @override
  Future<UserSettingsProfile> getProfile() => response;
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

class _Harness {
  static Future<_Harness> create() async {
    SharedPreferences.setMockInitialValues({});
    return _Harness(LocalCache(await SharedPreferences.getInstance()));
  }

  _Harness(LocalCache cache) {
    container = ProviderContainer(overrides: [
      localCacheProvider.overrideWithValue(cache),
      authControllerProvider.overrideWith((ref) => _Auth()),
      userDriversServiceProvider.overrideWithValue(references),
      userSettingsServiceProvider.overrideWithValue(profile),
      userDriversControllerProvider
          .overrideWith((ref) => UserDriversController(service: references)),
      userSubUsersControllerProvider.overrideWith((ref) =>
          UserSubUsersController(
              service: UserSubUserService(ApiClient(Dio())))),
    ]);
  }
  final references = _References();
  final profile = _Profile();
  late final ProviderContainer container;
  final requests = <Object>[];
  Future<Object?> Function(Object)? submission;
  Object? result;
  Future<void> open(WidgetTester tester,
      {bool driver = false,
      double width = 360,
      double scale = 1,
      double keyboard = 0}) async {
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
            theme: OpenVtsTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () async {
                          result = await showModalBottomSheet<Object>(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              builder: (_) => driver
                                  ? UserDriverCreateSheet(
                                      onSubmit: (request) async {
                                      requests.add(request);
                                      return await submission?.call(request)
                                          as UserDriver?;
                                    })
                                  : UserSubUserCreateSheet(
                                      onSubmit: (request) async {
                                      requests.add(request);
                                      return await submission?.call(request)
                                          as UserSubUser?;
                                    }));
                        },
                        child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  void dispose() => container.dispose();
}
