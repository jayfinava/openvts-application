import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/open_vts_colors.dart';
import '../../../core/theme/open_vts_spacing.dart';
import '../../../core/theme/open_vts_typography.dart';
import '../../../shared/helpers/toast_helper.dart';
import '../../../shared/widgets/open_vts_button.dart';
import '../../../shared/widgets/open_vts_card.dart';
import '../../../shared/widgets/open_vts_page_scaffold.dart';
import '../../../shared/widgets/open_vts_text_field.dart';

class ApiBaseUrlSettingsScreen extends ConsumerStatefulWidget {
  const ApiBaseUrlSettingsScreen({super.key});

  @override
  ConsumerState<ApiBaseUrlSettingsScreen> createState() =>
      _ApiBaseUrlSettingsScreenState();
}

class _ApiBaseUrlSettingsScreenState
    extends ConsumerState<ApiBaseUrlSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    _urlController =
        TextEditingController(text: ref.read(apiBaseUrlProvider));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;

    await ref
        .read(apiBaseUrlProvider.notifier)
        .saveCustomUrl(_urlController.text);

    if (!mounted) return;

    ToastHelper.show(context, 'Server URL updated');
    Navigator.of(context).pop();
  }

  Future<void> _reset() async {
    await ref.read(apiBaseUrlProvider.notifier).resetToDefault();
    _urlController.text = AppConfig.defaultApiBaseUrl;

    if (!mounted) return;

    ToastHelper.show(context, 'Server URL reset to default');
  }

  String? _validateUrl(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter a server URL';

    final uri = Uri.tryParse(trimmed);
    final hasValidScheme = uri?.scheme == 'http' || uri?.scheme == 'https';

    if (uri == null || !uri.isAbsolute || !hasValidScheme || uri.host.isEmpty) {
      return 'Enter a valid URL (e.g. http://192.168.1.10:3000/api)';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final activeUrl = ref.watch(apiBaseUrlProvider);
    final isUsingDefault = activeUrl == AppConfig.defaultApiBaseUrl;

    return OpenVtsPageScaffold(
      title: 'Server URL',
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OpenVtsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OpenVtsTextField(
                      label: 'Server URL',
                      controller: _urlController,
                      hintText: 'http://192.168.1.10:3000/api',
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.dns_rounded,
                      validator: _validateUrl,
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: OpenVtsSpacing.sm),
                    Text(
                      'Include the full path, e.g. http://192.168.1.10:3000/api',
                      style: OpenVtsTypography.meta.copyWith(
                        color: OpenVtsColors.textSecondary,
                      ),
                    ),
                    if (kIsWeb) ...[
                      const SizedBox(height: OpenVtsSpacing.xs),
                      Text(
                        'Web browsers require the server to allow cross-origin requests (CORS). If login fails with a connection error, enable CORS on your server.',
                        style: OpenVtsTypography.meta.copyWith(
                          color: OpenVtsColors.textSecondary,
                        ),
                      ),
                    ],
                    if (!isUsingDefault) ...[
                      const SizedBox(height: OpenVtsSpacing.sm),
                      GestureDetector(
                        onTap: _reset,
                        child: Text(
                          'Reset to default (${AppConfig.defaultApiBaseUrl})',
                          style: OpenVtsTypography.meta.copyWith(
                            color: OpenVtsColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: OpenVtsSpacing.lg),
              OpenVtsButton(
                label: 'Save',
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
