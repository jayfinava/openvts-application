import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../shared/widgets/open_vts_text_field.dart';

class AdminUserDropdownOption {
  const AdminUserDropdownOption({
    required this.value,
    required this.label,
    this.isFallback = false,
  });

  final String value;
  final String label;
  final bool isFallback;
}

class AdminUserFormSection extends StatelessWidget {
  const AdminUserFormSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: OpenVtsTypography.label.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: OpenVtsSpacing.sm),
        ...children,
      ],
    );
  }
}

class AdminUserDropdownField extends StatelessWidget {
  const AdminUserDropdownField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.hintText,
    this.prefixIcon,
    this.validator,
    this.isLoading = false,
    this.selectedLabel,
    super.key,
  });

  final String label;
  final String? value;
  final List<AdminUserDropdownOption> options;
  final ValueChanged<String?>? onChanged;
  final String? hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final bool isLoading;

  /// When non-null, overrides the text shown in the closed field for the
  /// selected value. The full [AdminUserDropdownOption.label] is still shown
  /// in the open menu. Has no effect on other dropdowns.
  final String? Function(String value)? selectedLabel;

  @override
  Widget build(BuildContext context) {
    final normalizedValue = _normalized(value);
    final menuItems = _menuItems(normalizedValue);
    final safeValue = menuItems.any((item) => item.value == normalizedValue)
        ? normalizedValue
        : null;
    final optionSignature = menuItems.map((item) => item.value ?? '').join('|');

    final resolvedSelectedLabel = selectedLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: OpenVtsTypography.label),
        const SizedBox(height: OpenVtsSpacing.xs),
        DropdownButtonFormField<String>(
          key: ValueKey('$label:${safeValue ?? ''}:$optionSignature'),
          initialValue: safeValue,
          isExpanded: true,
          items: menuItems,
          onChanged: isLoading ? null : onChanged,
          validator: validator,
          dropdownColor: Theme.of(context).colorScheme.surface,
          selectedItemBuilder: resolvedSelectedLabel == null
              ? null
              : (context) => menuItems.map((item) {
                    final compact = item.value == null
                        ? ''
                        : (resolvedSelectedLabel(item.value!) ?? item.value!);
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        compact,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: OpenVtsTypography.body.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(growable: false),
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon == null
                ? null
                : Icon(
                    prefixIcon,
                    size: 20,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            suffixIcon: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _menuItems(String? normalizedValue) {
    final distinctOptions = <AdminUserDropdownOption>[];
    final seen = <String>{};
    for (final option in options) {
      final optionValue = option.value.trim();
      if (optionValue.isEmpty || seen.contains(optionValue)) {
        continue;
      }
      seen.add(optionValue);
      distinctOptions.add(
        AdminUserDropdownOption(
          value: optionValue,
          label: option.label.trim().isEmpty ? optionValue : option.label,
          isFallback: option.isFallback,
        ),
      );
    }

    if (normalizedValue != null && !seen.contains(normalizedValue)) {
      distinctOptions.insert(
        0,
        AdminUserDropdownOption(
          value: normalizedValue,
          label: '$normalizedValue (current)',
          isFallback: true,
        ),
      );
    }

    return distinctOptions
        .map(
          (option) => DropdownMenuItem<String>(
            value: option.value,
            enabled: !option.isFallback,
            child: Builder(
              builder: (context) => Text(
                option.label,
                overflow: TextOverflow.ellipsis,
                style: OpenVtsTypography.body.copyWith(
                  color: option.isFallback
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);
  }
}

/// A responsive prefix + number row used by both edit-profile forms.
///
/// At ≥ 300 logical pixels it places the dropdown and text field side-by-side.
/// On narrower widths they stack vertically. The dropdown uses [selectedLabel]
/// so the closed field shows only the dial code (e.g. +91) while the open menu
/// still shows the full "+91 IN" label.
class AdminUserPrefixPhoneRow extends StatelessWidget {
  const AdminUserPrefixPhoneRow({
    required this.prefixValue,
    required this.prefixOptions,
    required this.onPrefixChanged,
    required this.phoneController,
    required this.phoneValidator,
    this.isLoading = false,
    super.key,
  });

  final String? prefixValue;
  final List<AdminUserDropdownOption> prefixOptions;
  final ValueChanged<String?> onPrefixChanged;
  final TextEditingController phoneController;
  final String? Function(String?)? phoneValidator;
  final bool isLoading;

  static const double _breakpoint = 300;
  static const double _prefixFlex = 0.38;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _breakpoint;

        final prefixField = AdminUserDropdownField(
          label: 'Mobile Prefix',
          value: prefixValue,
          options: prefixOptions,
          hintText: '+91',
          prefixIcon: Icons.phone_android_rounded,
          isLoading: isLoading,
          validator: requiredDropdown,
          selectedLabel: (v) => v,
          onChanged: onPrefixChanged,
        );

        final numberField = OpenVtsTextField(
          label: 'Mobile Number',
          controller: phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          prefixIcon: Icons.phone_rounded,
          validator: phoneValidator,
        );

        if (wide) {
          final prefixWidth =
              (constraints.maxWidth * _prefixFlex).clamp(90.0, 160.0);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: prefixWidth, child: prefixField),
              const SizedBox(width: OpenVtsSpacing.sm),
              Expanded(child: numberField),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            prefixField,
            const SizedBox(height: OpenVtsSpacing.sm),
            numberField,
          ],
        );
      },
    );
  }
}

String? requiredDropdown(String? value) {
  if (_normalized(value) == null) {
    return 'Required';
  }
  return null;
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}
