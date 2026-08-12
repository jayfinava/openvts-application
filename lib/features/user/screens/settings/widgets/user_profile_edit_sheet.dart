import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../core/utils/validators.dart';
import '../../../../../shared/widgets/open_vts_button.dart';
import '../../../../../shared/widgets/open_vts_searchable_dropdown.dart';
import '../../../controllers/user_providers.dart';
import '../../../controllers/user_settings_controller.dart';
import '../../../models/user_settings_model.dart';

class UserProfileEditSheet extends ConsumerStatefulWidget {
  const UserProfileEditSheet({
    required this.profile,
    required this.controller,
    super.key,
  });

  final UserSettingsProfile profile;
  final UserSettingsController controller;

  @override
  ConsumerState<UserProfileEditSheet> createState() =>
      _UserProfileEditSheetState();
}

class _UserProfileEditSheetState extends ConsumerState<UserProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _mobilePrefixController;
  late final TextEditingController _mobileNumberController;
  late final TextEditingController _addressController;
  late final TextEditingController _pincodeController;

  // Controlled selection state — always drives the dropdown value.
  late String _selectedCountry;
  late String _selectedState;
  late String _selectedCity;
  late String _selectedMobilePrefix;

  bool _isSaving = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final address = widget.profile.address;

    _nameController = TextEditingController(text: widget.profile.name ?? '');
    _emailController = TextEditingController(text: widget.profile.email ?? '');
    _mobilePrefixController =
        TextEditingController(text: widget.profile.mobilePrefix ?? '');
    _mobileNumberController =
        TextEditingController(text: widget.profile.mobileNumber ?? '');
    _addressController =
        TextEditingController(text: address?.addressLine ?? '');
    _pincodeController = TextEditingController(text: address?.pincode ?? '');

    _selectedCountry = (address?.countryCode ?? '').trim().toUpperCase();
    _selectedState = (address?.stateCode ?? '').trim().toUpperCase();
    _selectedCity = (address?.cityName ?? '').trim();
    _selectedMobilePrefix = (widget.profile.mobilePrefix ?? '').trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDependentOptions();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _mobilePrefixController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadDependentOptions() async {
    if (_selectedCountry.isNotEmpty) {
      await widget.controller.loadStates(_selectedCountry);
    }
    if (_selectedCountry.isNotEmpty && _selectedState.isNotEmpty) {
      await widget.controller.loadCities(_selectedCountry, _selectedState);
    }
  }

  Future<void> _onCountryChanged(String countryCode) async {
    final normalized = countryCode.trim().toUpperCase();
    // Immediately clear dependent selections so old values are never
    // visible while new options load.
    setState(() {
      _selectedCountry = normalized;
      _selectedState = '';
      _selectedCity = '';
      _submitError = null;
    });
    await widget.controller.loadStates(normalized);
  }

  Future<void> _onStateChanged(String stateCode) async {
    final normalized = stateCode.trim().toUpperCase();
    // Immediately clear city selection.
    setState(() {
      _selectedState = normalized;
      _selectedCity = '';
      _submitError = null;
    });
    await widget.controller.loadCities(_selectedCountry, normalized);
  }

  Future<void> _handleSave() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final normalizedName = _nameController.text.trim();
    final normalizedEmail = _emailController.text.trim();
    final normalizedPrefix = _effectivePrefix();
    final normalizedMobile = _mobileNumberController.text.trim();
    final normalizedAddress = _addressController.text.trim();
    final normalizedCountry = _effectiveCountry();
    final normalizedState = _effectiveState();
    final normalizedCity = _effectiveCity();
    final normalizedPincode = _pincodeController.text.trim();

    widget.controller.patchDraftProfile(
      name: normalizedName,
      email: normalizedEmail.isEmpty ? '' : normalizedEmail,
      mobilePrefix: normalizedPrefix,
      mobileNumber: normalizedMobile,
      addressLine: normalizedAddress,
      countryCode: normalizedCountry,
      stateCode: normalizedState,
      cityName: normalizedCity,
      pincode: normalizedPincode,
    );

    setState(() {
      _isSaving = true;
      _submitError = null;
    });

    final ok = await widget.controller.saveProfile();
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      if (!ok) {
        _submitError =
            ref.read(userSettingsControllerProvider).profileErrorMessage ??
                'Unable to save profile details.';
      }
    });

    if (ok) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userSettingsControllerProvider);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    final mobilePrefixOptions = state.mobilePrefixes;
    final countryOptions = state.countries;
    final stateOptions = state.states;
    final cityOptions = state.cities;

    // For controlled dropdowns the value must exist in the items list,
    // or be null (shows hint). Compute safe controlled values once.
    final safePrefix = _safeDropdownValue(
      _selectedMobilePrefix,
      mobilePrefixOptions.map((o) => o.value),
    );
    final safeCountry = _safeDropdownValue(
      _selectedCountry,
      countryOptions.map((o) => o.value),
    );
    // Only show a saved state selection when the loaded list actually belongs
    // to the current country – prevents stale options showing briefly.
    final statesAreForCurrentCountry =
        state.statesForCountryCode == _selectedCountry;
    final safeState = statesAreForCurrentCountry
        ? _safeDropdownValue(
            _selectedState,
            stateOptions.map((o) => o.value),
          )
        : null;

    // Only show a saved city selection when the loaded list belongs to the
    // current country+state pair.
    final expectedCityKey = '$_selectedCountry/$_selectedState';
    final citiesAreForCurrentSelection =
        state.citiesForCountryAndStateCode == expectedCityKey;
    final safeCity = citiesAreForCurrentSelection
        ? _safeDropdownValue(
            _selectedCity,
            cityOptions.map((o) => o.value),
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(OpenVtsRadius.lg),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            OpenVtsSpacing.md,
            OpenVtsSpacing.md,
            OpenVtsSpacing.md,
            OpenVtsSpacing.md + insets,
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profile',
                  style: OpenVtsTypography.label.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: OpenVtsSpacing.xxs),
                Text(
                  'Update personal and address details. '
                  'Changes are saved only when you confirm.',
                  style: OpenVtsTypography.meta.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: OpenVtsSpacing.sm),
                _textField(
                  controller: _nameController,
                  label: 'Name',
                  textInputAction: TextInputAction.next,
                  validator: Validators.adminName,
                ),
                const SizedBox(height: OpenVtsSpacing.xs),
                _textField(
                  controller: _emailController,
                  label: 'Email (optional)',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.adminEmailOptional,
                ),
                const SizedBox(height: OpenVtsSpacing.xs),
                if (mobilePrefixOptions.isEmpty)
                  _textField(
                    controller: _mobilePrefixController,
                    label: 'Mobile Prefix',
                    hint: '+1',
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    validator: Validators.mobilePrefix,
                  )
                else
                  OpenVtsSearchableDropdown<String>(
                    key: ValueKey('prefix_${mobilePrefixOptions.length}'),
                    label: 'Mobile Prefix',
                    value: safePrefix,
                    options: mobilePrefixOptions
                        .map(
                          (option) => OpenVtsDropdownOption<String>(
                            value: option.value,
                            label: option.label,
                            subtitle: option.countryCode.isNotEmpty
                                ? option.countryCode
                                : null,
                            searchText: '${option.value} ${option.countryCode}',
                          ),
                        )
                        .toList(growable: false),
                    searchHintText: 'Dial code or country',
                    sheetTitle: 'Select Mobile Prefix',
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMobilePrefix = value;
                        _mobilePrefixController.text = value;
                      });
                    },
                  ),
                const SizedBox(height: OpenVtsSpacing.xs),
                _textField(
                  controller: _mobileNumberController,
                  label: 'Mobile Number',
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      Validators.maxMobileNumberLength,
                    ),
                  ],
                  validator: Validators.mobileNumber,
                ),
                const SizedBox(height: OpenVtsSpacing.xs),
                _textField(
                  controller: _addressController,
                  label: 'Address Line',
                  textInputAction: TextInputAction.next,
                  validator: Validators.address,
                ),
                const SizedBox(height: OpenVtsSpacing.xs),
                if (countryOptions.isEmpty)
                  _textField(
                    controller: TextEditingController(text: _selectedCountry),
                    label: 'Country Code',
                    hint: 'US',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final country = (value ?? '').trim();
                      if (country.isEmpty) return 'Country is required.';
                      return null;
                    },
                  )
                else
                  _controlledDropdownField<String>(
                    key: ValueKey('country_${countryOptions.length}'),
                    label: 'Country',
                    value: safeCountry,
                    items: countryOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.value,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      _onCountryChanged(value);
                    },
                  ),
                const SizedBox(height: OpenVtsSpacing.xs),
                // State field — shows loading indicator or dropdown/text.
                if (state.isLoadingStates)
                  _LoadingFieldPlaceholder(label: 'State')
                else if (stateOptions.isEmpty && statesAreForCurrentCountry)
                  _textField(
                    controller: TextEditingController(text: _selectedState),
                    label: 'State Code',
                    hint: 'CA',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final s = (value ?? '').trim();
                      if (s.isEmpty) return 'State is required.';
                      return null;
                    },
                  )
                else if (!statesAreForCurrentCountry &&
                    _selectedCountry.isEmpty)
                  _textField(
                    controller: TextEditingController(text: _selectedState),
                    label: 'State Code',
                    hint: 'Select country first',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final s = (value ?? '').trim();
                      if (s.isEmpty) return 'State is required.';
                      return null;
                    },
                  )
                else if (stateOptions.isNotEmpty)
                  _controlledDropdownField<String>(
                    // ValueKey ensures the dropdown rebuilds entirely when the
                    // country changes and a new list arrives; prevents the old
                    // FormField internal value from persisting.
                    key: ValueKey(
                      'state_${state.statesForCountryCode}_'
                      '${stateOptions.length}',
                    ),
                    label: 'State',
                    value: safeState,
                    items: stateOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.value,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      _onStateChanged(value);
                    },
                  )
                else
                  _textField(
                    controller: TextEditingController(text: _selectedState),
                    label: 'State Code',
                    hint: 'CA',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final s = (value ?? '').trim();
                      if (s.isEmpty) return 'State is required.';
                      return null;
                    },
                  ),
                const SizedBox(height: OpenVtsSpacing.xs),
                // City field — shows loading indicator or dropdown/text.
                if (state.isLoadingCities)
                  _LoadingFieldPlaceholder(label: 'City')
                else if (cityOptions.isEmpty && citiesAreForCurrentSelection)
                  _textField(
                    controller: TextEditingController(text: _selectedCity),
                    label: 'City',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final c = (value ?? '').trim();
                      if (c.isEmpty) return 'City is required.';
                      return null;
                    },
                  )
                else if (cityOptions.isNotEmpty)
                  _controlledDropdownField<String>(
                    key: ValueKey(
                      'city_${state.citiesForCountryAndStateCode}_'
                      '${cityOptions.length}',
                    ),
                    label: 'City',
                    value: safeCity,
                    items: cityOptions
                        .map(
                          (option) => DropdownMenuItem<String>(
                            value: option.value,
                            child: Text(
                              option.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedCity = value;
                      });
                    },
                  )
                else
                  _textField(
                    controller: TextEditingController(text: _selectedCity),
                    label: 'City',
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      final c = (value ?? '').trim();
                      if (c.isEmpty) return 'City is required.';
                      return null;
                    },
                  ),
                const SizedBox(height: OpenVtsSpacing.xs),
                _textField(
                  controller: _pincodeController,
                  label: 'Pincode',
                  hint: 'Optional',
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(
                      Validators.maxPincodeLength,
                    ),
                  ],
                  validator: Validators.pincodeOptional,
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: OpenVtsSpacing.xs),
                  Text(
                    _submitError!,
                    style: OpenVtsTypography.meta.copyWith(
                      color: OpenVtsColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: OpenVtsSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: OpenVtsButton(
                        label: 'Cancel',
                        variant: OpenVtsButtonVariant.secondary,
                        height: 44,
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.of(context).pop(false),
                      ),
                    ),
                    const SizedBox(width: OpenVtsSpacing.xs),
                    Expanded(
                      child: OpenVtsButton(
                        label: 'Save Profile',
                        height: 44,
                        isLoading: _isSaving,
                        onPressed: _isSaving ? null : _handleSave,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Field helpers ─────────────────────────────────────────────────────────

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  /// Fully controlled dropdown: [value] drives the visible selection; the
  /// [key] forces a full widget replacement when the option list changes so
  /// the FormField's internal cache can never show a stale value.
  Widget _controlledDropdownField<T>({
    required Key key,
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      key: key,
      value: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
      validator: (v) {
        if (v == null || (v is String && v.trim().isEmpty)) {
          return '$label is required.';
        }
        return null;
      },
    );
  }

  T? _safeDropdownValue<T>(T value, Iterable<T> values) {
    for (final item in values) {
      if (item == value) return item;
    }
    return null;
  }

  String _effectivePrefix() {
    final selected = _selectedMobilePrefix.trim();
    if (selected.isNotEmpty) return selected;
    return _mobilePrefixController.text.trim();
  }

  String _effectiveCountry() {
    final selected = _selectedCountry.trim().toUpperCase();
    if (selected.isNotEmpty) return selected;
    return '';
  }

  String _effectiveState() {
    final selected = _selectedState.trim().toUpperCase();
    if (selected.isNotEmpty) return selected;
    return '';
  }

  String _effectiveCity() {
    final selected = _selectedCity.trim();
    if (selected.isNotEmpty) return selected;
    return '';
  }
}

/// Placeholder that shows a disabled-looking row while states/cities load.
class _LoadingFieldPlaceholder extends StatelessWidget {
  const _LoadingFieldPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const SizedBox.square(
          dimension: 20,
          child: Padding(
            padding: EdgeInsets.all(2),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      child: const SizedBox(height: 20),
    );
  }
}
