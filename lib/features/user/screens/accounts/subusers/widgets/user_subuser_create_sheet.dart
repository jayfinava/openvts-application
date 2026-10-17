import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/access/workspace_scope_provider.dart';
import '../../../../../../core/errors/error_mapper.dart';
import '../../../../../../shared/helpers/mobile_text.dart';
import '../../../../../../shared/helpers/toast_helper.dart';
import '../../../../../../shared/widgets/open_vts_searchable_dropdown.dart';
import '../../../../../../shared/widgets/open_vts_text_field.dart';
import '../../../../controllers/user_providers.dart';
import '../../../../models/user_driver_model.dart';
import '../../../../models/user_subuser_model.dart';
import '../../../../utils/user_account_form_rules.dart';
import '../../widgets/user_account_form_sheet.dart';

class UserSubUserCreateSheet extends ConsumerStatefulWidget {
  const UserSubUserCreateSheet({required this.onSubmit, super.key});
  final Future<UserSubUser?> Function(CreateUserSubUserRequest request)
      onSubmit;
  @override
  ConsumerState<UserSubUserCreateSheet> createState() =>
      _UserSubUserCreateSheetState();
}

class _UserSubUserCreateSheetState
    extends ConsumerState<UserSubUserCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(), _username = TextEditingController();
  final _email = TextEditingController(), _mobile = TextEditingController();
  final _password = TextEditingController();
  late final String _scope;
  List<UserDriverMobilePrefixOption> _prefixes = [];
  String? _prefix;
  bool _loading = true, _loadFailed = false, _active = true;
  bool _obscure = true, _submitting = false, _attempted = false;
  bool get _current =>
      mounted && ref.read(workspaceDataScopeProvider) == _scope;

  @override
  void initState() {
    super.initState();
    _scope = ref.read(workspaceDataScopeProvider);
    _loadPrefixes();
  }

  @override
  void dispose() {
    for (final field in [_name, _username, _email, _mobile, _password]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _loadPrefixes() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final values =
          await ref.read(userDriversServiceProvider).fetchMobilePrefixes();
      if (!mounted || !_current) return;
      setState(() {
        _prefixes = values;
        _loading = false;
        _loadFailed = values.isEmpty;
      });
    } catch (_) {
      if (mounted && _current) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _submitting ||
        ref.watch(userSubUsersControllerProvider.select((s) => s.isCreating));
    return UserAccountFormSheet(
        formKey: _formKey,
        title: context.mobileText('Create Sub User'),
        submitting: busy,
        attempted: _attempted,
        onSubmit: _submit,
        fields: [
          OpenVtsTextField(
              label: context.mobileText('Name'),
              controller: _name,
              maxLength: UserAccountFormRules.nameMax,
              enabled: !busy,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              validator: UserAccountFormRules.name),
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
                hintText: context.mobileText('Select'),
                searchHintText: 'Search code or country',
                options: [
                  OpenVtsDropdownOption(
                      value: '', label: context.mobileText('None')),
                  for (final item in _prefixes)
                    OpenVtsDropdownOption(
                        value: item.value,
                        label: item.value,
                        subtitle: item.label,
                        searchText: item.label),
                ],
                enabled: !busy && !_loading && !_loadFailed,
                isLoading: _loading,
                validator: (_) => UserAccountFormRules.prefix(_prefix,
                    number: _mobile.text, required: false),
                onChanged: (value) =>
                    setState(() => _prefix = value == '' ? null : value));
            final number = OpenVtsTextField(
                label: context.mobileText('Mobile (optional)'),
                controller: _mobile,
                enabled: !busy,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                maxLength: UserAccountFormRules.mobileMax,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) =>
                    UserAccountFormRules.mobile(value, required: false));
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
          if (_loadFailed)
            TextButton(
                onPressed: busy ? null : _loadPrefixes,
                child: Text('${context.mobileText('Unable to load form options.')} ${context.mobileText('Retry')}')),
          OpenVtsTextField(
              label: context.mobileText('Username (optional)'),
              controller: _username,
              maxLength: UserAccountFormRules.usernameMax,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.username],
              validator: (value) =>
                  UserAccountFormRules.username(value, required: false)),
          OpenVtsTextField(
              label: context.mobileText('Password'),
              controller: _password,
              maxLength: UserAccountFormRules.passwordMax,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              obscureText: _obscure,
              suffixIcon: IconButton(
                  onPressed:
                      busy ? null : () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined)),
              validator: UserAccountFormRules.password),
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.mobileText('Active')),
              value: _active,
              onChanged:
                  busy ? null : (value) => setState(() => _active = value)),
        ]);
  }

  Future<void> _submit() async {
    if (!_current ||
        _submitting ||
        ref.read(userSubUsersControllerProvider).isCreating) {
      return;
    }
    setState(() => _attempted = true);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final result = await widget.onSubmit(CreateUserSubUserRequest(
          name: UserAccountFormRules.display(_name.text),
          username: _optional(_username.text),
          email: _optional(UserAccountFormRules.emailValue(_email.text)),
          mobilePrefix: _optional(_prefix),
          mobileNumber: _optional(UserAccountFormRules.digits(_mobile.text)),
          password: _password.text,
          isActive: _active));
      if (!mounted || !_current) return;
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        ToastHelper.showError(
            ref.read(userSubUsersControllerProvider).errorMessage ??
                context.mobileText('Unable to create sub user.'),
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

  String? _optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
}
