import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../../../shared/widgets/open_vts_button.dart';
import '../../../../../shared/widgets/open_vts_card.dart';
import '../../../models/user_settings_model.dart';

class UserSettingsSaveBar extends StatelessWidget {
  const UserSettingsSaveBar({
    required this.selectedTab,
    required this.isSaving,
    required this.canSave,
    required this.canReset,
    required this.onSave,
    required this.onReset,
    super.key,
  });

  final UserSettingsTab selectedTab;
  final bool isSaving;
  final bool canSave;
  final bool canReset;
  final VoidCallback? onSave;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final tabLabel = selectedTab == UserSettingsTab.profile
        ? l10n.profile
        : l10n.localization;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(
          OpenVtsSpacing.sm,
          OpenVtsSpacing.xs,
          OpenVtsSpacing.sm,
          OpenVtsSpacing.xs,
        ),
        child: OpenVtsCard(
          padding: const EdgeInsets.all(OpenVtsSpacing.xs),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final helperText = isSaving
                  ? 'Saving $tabLabel changes...'
                  : 'You have unsaved $tabLabel changes.';

              if (constraints.maxWidth < 430) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helperText,
                      style: OpenVtsTypography.meta.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: OpenVtsSpacing.xs),
                    Row(
                      children: [
                        Expanded(
                          child: OpenVtsButton(
                            label: l10n.reset,
                            height: 44,
                            variant: OpenVtsButtonVariant.secondary,
                            onPressed: canReset ? onReset : null,
                          ),
                        ),
                        const SizedBox(width: OpenVtsSpacing.xs),
                        Expanded(
                          flex: 2,
                          child: OpenVtsButton(
                            label: isSaving ? l10n.loading : l10n.save,
                            height: 44,
                            isLoading: isSaving,
                            onPressed: canSave ? onSave : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: Text(
                      helperText,
                      style: OpenVtsTypography.meta.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 92,
                    child: OpenVtsButton(
                      label: l10n.reset,
                      height: 44,
                      variant: OpenVtsButtonVariant.secondary,
                      onPressed: canReset ? onReset : null,
                    ),
                  ),
                  const SizedBox(width: OpenVtsSpacing.xs),
                  SizedBox(
                    width: 120,
                    child: OpenVtsButton(
                      label: isSaving ? l10n.loading : l10n.save,
                      height: 44,
                      isLoading: isSaving,
                      onPressed: canSave ? onSave : null,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
