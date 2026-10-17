import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/access/workspace_scope_provider.dart';
import '../../../../../../core/errors/error_mapper.dart';
import '../../../../../../shared/helpers/mobile_text.dart';
import '../../../../../../shared/helpers/toast_helper.dart';
import '../../../../../../shared/widgets/open_vts_searchable_dropdown.dart';
import '../../../../../../shared/widgets/open_vts_text_field.dart';
import '../../../../../auth/controllers/auth_controller.dart';
import '../../../../controllers/user_providers.dart';
import '../../../../models/user_driver_model.dart';
import '../../../../utils/user_account_form_rules.dart';
import '../../widgets/user_account_form_sheet.dart';

class UserDriverCreateSheet extends ConsumerStatefulWidget {
  const UserDriverCreateSheet({required this.onSubmit, super.key});
  final Future<UserDriver?> Function(CreateUserDriverRequest request) onSubmit;
  @override
  ConsumerState<UserDriverCreateSheet> createState() =>
      _UserDriverCreateSheetState();
}

class _UserDriverCreateSheetState extends ConsumerState<UserDriverCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(), _username = TextEditingController();
  final _password = TextEditingController(), _mobile = TextEditingController();
  final _email = TextEditingController(), _address = TextEditingController();
  final _postal = TextEditingController();
  late final String _scope;
  List<UserDriverMobilePrefixOption> _prefixes = [];
  List<UserDriverCountryOption> _countries = [];
  List<UserDriverStateOption> _states = [];
  List<UserDriverCityOption> _cities = [];
  String? _prefix = '+91', _country, _state, _city, _defaultCountry;
  bool _countryTouched = false,
      _loadingCountries = true,
      _loadingPrefixes = true;
  bool _countriesFailed = false, _prefixesFailed = false;
  bool _loadingStates = false,
      _loadingCities = false,
      _statesFailed = false,
      _citiesFailed = false;
  bool _obscure = true, _submitting = false, _attempted = false;
  int _statesSerial = 0, _citiesSerial = 0;
  bool get _current =>
      mounted && ref.read(workspaceDataScopeProvider) == _scope;

  @override
  void initState() {
    super.initState();
    _scope = ref.read(workspaceDataScopeProvider);
    unawaited(_loadCountries());
    unawaited(_loadPrefixes());
    unawaited(_loadOwnCountry());
  }

  @override
  void dispose() {
    for (final field in [
      _name,
      _username,
      _password,
      _mobile,
      _email,
      _address,
      _postal
    ]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countriesFailed = false;
    });
    try {
      final values =
          await ref.read(userDriversServiceProvider).fetchCountries();
      if (!mounted || !_current) return;
      setState(() {
        _countries = values;
        _loadingCountries = false;
        _countriesFailed = values.isEmpty;
      });
      _applyCountryDefault();
    } catch (_) {
      if (mounted && _current) {
        setState(() {
          _loadingCountries = false;
          _countriesFailed = true;
        });
      }
    }
  }

  Future<void> _loadPrefixes() async {
    setState(() {
      _loadingPrefixes = true;
      _prefixesFailed = false;
    });
    try {
      final values =
          await ref.read(userDriversServiceProvider).fetchMobilePrefixes();
      if (!mounted || !_current) return;
      setState(() {
        _prefixes = values;
        _loadingPrefixes = false;
        _prefixesFailed = values.isEmpty;
      });
    } catch (_) {
      if (mounted && _current) {
        setState(() {
          _loadingPrefixes = false;
          _prefixesFailed = true;
        });
      }
    }
  }

  Future<void> _loadOwnCountry() async {
    try {
      final actor = ref.read(authControllerProvider).user;
      final profile = await ref.read(userSettingsServiceProvider).getProfile();
      if (!_current || actor == null || profile.uid?.toString() != actor.id) {
        return;
      }
      _defaultCountry = profile.address?.countryCode?.trim().toUpperCase();
      _applyCountryDefault();
    } catch (_) {/* Optional default: manual country selection still works. */}
  }

  void _applyCountryDefault() {
    if (!_current ||
        _countryTouched ||
        _country != null ||
        _defaultCountry == null) {
      return;
    }
    for (final item in _countries) {
      if (item.value.toUpperCase() == _defaultCountry) {
        unawaited(_changeCountry(item.value, manual: false));
        break;
      }
    }
  }

  Future<void> _changeCountry(String? value, {bool manual = true}) async {
    if (!mounted || !_current) return;
    if (manual) _countryTouched = true;
    final country = value == null || value.isEmpty ? null : value;
    if (country == _country) return;
    setState(() {
      _country = country;
      _state = null;
      _city = null;
      _states = [];
      _cities = [];
      _statesSerial++;
      _citiesSerial++;
      _loadingStates = false;
      _loadingCities = false;
      _statesFailed = false;
      _citiesFailed = false;
    });
    await _loadStates();
  }

  Future<void> _changeState(String? value) async {
    if (!mounted || !_current) return;
    final state = value == null || value.isEmpty ? null : value;
    if (state == _state) return;
    setState(() {
      _state = state;
      _city = null;
      _cities = [];
      _citiesSerial++;
      _loadingCities = false;
      _citiesFailed = false;
    });
    await _loadCities();
  }

  Future<void> _loadStates() async {
    final country = _country;
    if (!_current || country == null) return;
    final serial = ++_statesSerial;
    setState(() {
      _loadingStates = true;
      _statesFailed = false;
    });
    try {
      final values =
          await ref.read(userDriversServiceProvider).fetchStates(country);
      if (!_current || serial != _statesSerial || country != _country) return;
      setState(() {
        _states = values;
        _loadingStates = false;
      });
    } catch (_) {
      if (_current && serial == _statesSerial) {
        setState(() {
          _loadingStates = false;
          _statesFailed = true;
        });
      }
    }
  }

  Future<void> _loadCities() async {
    final country = _country, state = _state;
    if (!_current || country == null || state == null) return;
    final serial = ++_citiesSerial;
    setState(() {
      _loadingCities = true;
      _citiesFailed = false;
    });
    try {
      final values = await ref
          .read(userDriversServiceProvider)
          .fetchCities(country, state);
      if (!_current ||
          serial != _citiesSerial ||
          country != _country ||
          state != _state) {
        return;
      }
      setState(() {
        _cities = values;
        _loadingCities = false;
      });
    } catch (_) {
      if (_current && serial == _citiesSerial) {
        setState(() {
          _loadingCities = false;
          _citiesFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting ||
        ref.watch(userDriversControllerProvider.select((s) => s.isCreating));
    final prefixOptions = <String, OpenVtsDropdownOption<String>>{
      for (final item in _prefixes)
        item.value: OpenVtsDropdownOption(
            value: item.value,
            label: item.value,
            subtitle: item.label,
            searchText: item.label),
      if (_prefix != null && !_prefixes.any((item) => item.value == _prefix))
        _prefix!: OpenVtsDropdownOption(value: _prefix!, label: _prefix!),
    };
    return UserAccountFormSheet(
        formKey: _formKey,
        title: context.mobileText('Create Driver'),
        submitting: busy,
        attempted: _attempted,
        onSubmit: _submit,
        fields: [
          if (_loadingCountries || _loadingPrefixes)
            const LinearProgressIndicator(minHeight: 2),
          if (_countriesFailed || _prefixesFailed)
            TextButton(
                onPressed: busy
                    ? null
                    : () {
                        if (_countriesFailed) unawaited(_loadCountries());
                        if (_prefixesFailed) unawaited(_loadPrefixes());
                      },
                child: Text('${context.mobileText('Unable to load form options.')} ${context.mobileText('Retry')}')),
          OpenVtsTextField(
              label: context.mobileText('Name'),
              controller: _name,
              maxLength: UserAccountFormRules.nameMax,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: UserAccountFormRules.name),
          OpenVtsTextField(
              label: context.mobileText('Username'),
              controller: _username,
              maxLength: UserAccountFormRules.usernameMax,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: UserAccountFormRules.username),
          OpenVtsTextField(
              label: context.mobileText('Email (optional)'),
              controller: _email,
              maxLength: UserAccountFormRules.emailMax,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: UserAccountFormRules.email),
          LayoutBuilder(builder: (context, box) {
            final code = OpenVtsSearchableDropdown<String>(
                label: context.mobileText('Prefix'),
                value: _prefix,
                hintText: '+91',
                options: prefixOptions.values.toList(),
                searchHintText: 'Search code or country',
                required: true,
                enabled: !busy && !_loadingPrefixes,
                isLoading: _loadingPrefixes,
                validator: (_) => UserAccountFormRules.prefix(_prefix),
                onChanged: (value) => setState(() => _prefix = value));
            final number = OpenVtsTextField(
                label: context.mobileText('Mobile'),
                controller: _mobile,
                maxLength: UserAccountFormRules.mobileMax,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: UserAccountFormRules.mobile);
            if (box.maxWidth < 400 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3) {
              return Column(
                  children: [code, const SizedBox(height: 12), number]);
            }
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(width: 140, child: code),
              const SizedBox(width: 12),
              Expanded(child: number)
            ]);
          }),
          OpenVtsTextField(
              label: context.mobileText('Password'),
              controller: _password,
              maxLength: UserAccountFormRules.passwordMax,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscure,
              suffixIcon: IconButton(
                  onPressed:
                      busy ? null : () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined)),
              validator: UserAccountFormRules.password),
          OpenVtsTextField(
              label: context.mobileText('Address (optional)'),
              controller: _address,
              maxLength: UserAccountFormRules.addressMax,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.streetAddressLine1],
              validator: UserAccountFormRules.address),
          OpenVtsSearchableDropdown<String>(
              label: context.mobileText('Country'),
              value: _country,
              options: [
                OpenVtsDropdownOption(
                    value: '', label: context.mobileText('Select country')),
                for (final item in _countries)
                  OpenVtsDropdownOption(value: item.value, label: item.label),
              ],
              required: true,
              enabled: !busy && !_loadingCountries,
              isLoading: _loadingCountries,
              searchHintText: 'Search country',
              hintText: context.mobileText('Select country'),
              onChanged: (value) => unawaited(_changeCountry(value))),
          OpenVtsSearchableDropdown<String>(
              label: context.mobileText('State (optional)'),
              value: _state,
              options: [
                OpenVtsDropdownOption(
                    value: '', label: context.mobileText('None')),
                for (final item in _states)
                  OpenVtsDropdownOption(value: item.value, label: item.label)
              ],
              enabled: !busy &&
                  _country != null &&
                  !_loadingStates &&
                  !_statesFailed,
              isLoading: _loadingStates,
              searchHintText: 'Search state',
              hintText: context.mobileText('Select state'),
              onChanged: (value) => unawaited(_changeState(value))),
          if (_statesFailed)
            TextButton(
                onPressed: busy ? null : _loadStates,
                child: Text(context.mobileText('Retry'))),
          OpenVtsSearchableDropdown<String>(
              label: context.mobileText('City (optional)'),
              value: _city,
              options: [
                OpenVtsDropdownOption(
                    value: '', label: context.mobileText('None')),
                for (final item in _cities)
                  OpenVtsDropdownOption(value: item.value, label: item.label)
              ],
              enabled: !busy &&
                  _country != null &&
                  _state != null &&
                  !_loadingCities &&
                  !_citiesFailed,
              isLoading: _loadingCities,
              searchHintText: 'Search city',
              hintText: context.mobileText('Select city'),
              onChanged: (value) =>
                  setState(() => _city = value == '' ? null : value)),
          if (_citiesFailed)
            TextButton(
                onPressed: busy ? null : _loadCities,
                child: Text(context.mobileText('Retry'))),
          OpenVtsTextField(
              label: context.mobileText('Pincode (optional)'),
              controller: _postal,
              maxLength: UserAccountFormRules.postalMax,
              enabled: !busy,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.postalCode],
              validator: UserAccountFormRules.postal),
        ]);
  }

  Future<void> _submit() async {
    if (!_current ||
        _submitting ||
        ref.read(userDriversControllerProvider).isCreating) {
      return;
    }
    setState(() => _attempted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.onSubmit(CreateUserDriverRequest(
          name: UserAccountFormRules.display(_name.text),
          username: _username.text.trim(),
          email: _optional(UserAccountFormRules.emailValue(_email.text)),
          password: _password.text,
          mobilePrefix: _prefix!.trim(),
          mobile: UserAccountFormRules.digits(_mobile.text),
          countryCode: _country!,
          stateCode: _state,
          city: _city,
          address: _optional(UserAccountFormRules.display(_address.text)),
          pincode: _optional(UserAccountFormRules.display(_postal.text))));
      if (!mounted || !_current) return;
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        ToastHelper.showError(
            ref.read(userDriversControllerProvider).errorMessage ??
                context.mobileText('Unable to create driver.'),
            context: context);
      }
    } catch (error) {
      if (mounted && _current) {
        ToastHelper.showError(ErrorMapper.from(error).message,
            context: context);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _optional(String value) => value.isEmpty ? null : value;
}
