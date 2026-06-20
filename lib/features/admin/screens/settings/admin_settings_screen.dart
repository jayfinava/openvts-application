import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/open_vts_colors.dart';
import '../../../../core/theme/open_vts_radius.dart';
import '../../../../core/theme/open_vts_spacing.dart';
import '../../../../core/theme/open_vts_typography.dart';
import '../../../../shared/widgets/open_vts_card.dart';
import '../../../../shared/widgets/open_vts_page_scaffold.dart';
import '../../controllers/admin_providers.dart';
import '../../models/admin_settings_model.dart';
import '../../models/admin_settings_state.dart';
import 'widgets/admin_localization_settings_section.dart';
import 'widgets/admin_profile_settings_section.dart';
import 'widgets/admin_smtp_settings_section.dart';

class AdminSettingsScreen extends ConsumerStatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  ConsumerState<AdminSettingsScreen> createState() =>
      _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends ConsumerState<AdminSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
          ref.read(adminSettingsControllerProvider.notifier).loadInitial());
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminSettingsControllerProvider);
    return OpenVtsPageScaffold(
      title: 'Settings',
      headerMode: OpenVtsPageHeaderMode.closeable,
      padding: const EdgeInsets.fromLTRB(
        OpenVtsSpacing.sm,
        OpenVtsSpacing.sm,
        OpenVtsSpacing.sm,
        OpenVtsSpacing.md,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(adminSettingsControllerProvider.notifier)
            .refreshCurrentSection(),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const _SettingsHeader(),
            const SizedBox(height: OpenVtsSpacing.sm),
            _SectionSelector(selected: state.selectedSection),
            const SizedBox(height: OpenVtsSpacing.sm),
            _SectionContent(state: state),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return OpenVtsCard(
      padding: const EdgeInsets.symmetric(
        horizontal: OpenVtsSpacing.md,
        vertical: OpenVtsSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: OpenVtsColors.brandInk,
              borderRadius: BorderRadius.circular(OpenVtsRadius.md),
            ),
            child: const Icon(
              Icons.tune_rounded,
              size: 18,
              color: OpenVtsColors.white,
            ),
          ),
          const SizedBox(width: OpenVtsSpacing.sm),
          Expanded(
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontFamily: OpenVtsTypography.primaryFontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Manage profile, localization and SMTP settings.',
                    style: TextStyle(
                      fontFamily: OpenVtsTypography.primaryFontFamily,
                      fontSize: 11.5,
                      height: 1.35,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionItem {
  const _SectionItem(this.section, this.label, this.icon);
  final AdminSettingsSection section;
  final String label;
  final IconData icon;
}

const _kSections = <_SectionItem>[
  _SectionItem(
      AdminSettingsSection.profile, 'Profile', Icons.person_outline_rounded),
  _SectionItem(
      AdminSettingsSection.localization, 'Localization', Icons.public_rounded),
  _SectionItem(AdminSettingsSection.smtp, 'SMTP', Icons.mail_outline_rounded),
];

class _SectionSelector extends ConsumerWidget {
  const _SectionSelector({required this.selected});

  final AdminSettingsSection selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        physics: const BouncingScrollPhysics(),
        itemCount: _kSections.length,
        separatorBuilder: (_, __) => const SizedBox(width: OpenVtsSpacing.xs),
        itemBuilder: (context, index) {
          final item = _kSections[index];
          final isSelected = item.section == selected;
          return _SectionChip(
            item: item,
            isSelected: isSelected,
            onTap: () {
              ref
                  .read(adminSettingsControllerProvider.notifier)
                  .selectSection(item.section);
            },
          );
        },
      ),
    );
  }
}

class _SectionChip extends StatelessWidget {
  const _SectionChip({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _SectionItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isSelected ? scheme.primary : scheme.surfaceContainer;
    final fg = isSelected ? scheme.onPrimary : scheme.onSurface;
    final borderColor = isSelected ? scheme.primary : scheme.outlineVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OpenVtsSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                item.label,
                style: TextStyle(
                  fontFamily: OpenVtsTypography.primaryFontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionContent extends StatelessWidget {
  const _SectionContent({required this.state});

  final AdminSettingsState state;

  @override
  Widget build(BuildContext context) {
    switch (state.selectedSection) {
      case AdminSettingsSection.profile:
        return ProfileSettingsSection(state: state);
      case AdminSettingsSection.localization:
        return LocalizationSettingsSection(state: state);
      case AdminSettingsSection.smtp:
        return SmtpSettingsSection(state: state);
    }
  }
}
