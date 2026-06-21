import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../shared/widgets/open_vts_card.dart';
import '../../../../../shared/widgets/open_vts_date_time_range_selector.dart';
import '../../../models/admin_payments_model.dart';
import '../../../models/admin_payments_state.dart';
import '../../../models/admin_users_model.dart';

class AdminPaymentsFiltersCard extends StatelessWidget {
  const AdminPaymentsFiltersCard({
    required this.state,
    required this.onUserChanged,
    required this.onStatusChanged,
    required this.onModeChanged,
    required this.onRangePresetChanged,
    required this.onCustomRangeChanged,
    required this.onClear,
    required this.onApply,
    super.key,
  });

  final AdminPaymentsState state;
  final ValueChanged<String?> onUserChanged;
  final ValueChanged<AdminPaymentStatus?> onStatusChanged;
  final ValueChanged<AdminPaymentMode?> onModeChanged;
  final ValueChanged<AdminPaymentsRangePreset> onRangePresetChanged;
  final void Function(DateTime? from, DateTime? to) onCustomRangeChanged;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : OpenVtsColors.textPrimary;
    final subheadingColor =
        isDark ? Colors.grey[300] : OpenVtsColors.textSecondary;
    final iconColor = isDark ? Colors.white : OpenVtsColors.textPrimary;
    final iconBgColor = isDark ? Colors.black : OpenVtsColors.surfaceElevated;

    return OpenVtsCard(
      padding: const EdgeInsets.all(OpenVtsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                  border: Border.all(color: OpenVtsColors.border),
                ),
                child: Icon(
                  Icons.filter_list_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: OpenVtsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters',
                        style: OpenVtsTypography.titleSmall
                            .copyWith(color: headingColor)),
                    const SizedBox(height: OpenVtsSpacing.xxs),
                    Text(
                      'Refine payments by user, status, mode, and date.',
                      style: OpenVtsTypography.meta.copyWith(
                        color: subheadingColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OpenVtsSpacing.md),
          _buildFilterFields(),
          const SizedBox(height: OpenVtsSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.hasActiveFilters ? onClear : null,
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    side: const BorderSide(color: OpenVtsColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: OpenVtsSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApply,
                  icon: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.white : Colors.white,
                  ),
                  label: Text(
                    'Apply Filters',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.white,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor:
                        isDark ? Colors.black : OpenVtsColors.brandInk,
                    side: BorderSide(
                      color: isDark ? Colors.white : Colors.transparent,
                      width: isDark ? 1 : 0,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                    ),
                    foregroundColor: isDark ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;

        if (isWide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildUserDropdown()),
                  const SizedBox(width: OpenVtsSpacing.sm),
                  Expanded(child: _buildStatusDropdown()),
                ],
              ),
              const SizedBox(height: OpenVtsSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPaymentModeDropdown()),
                  const SizedBox(width: OpenVtsSpacing.sm),
                  Expanded(child: _buildDateRangeDropdown()),
                ],
              ),
              if (state.rangePreset == AdminPaymentsRangePreset.custom) ...[
                const SizedBox(height: OpenVtsSpacing.sm),
                _buildCustomDateRangeField(),
              ],
            ],
          );
        } else {
          return Column(
            children: [
              _buildUserDropdown(),
              const SizedBox(height: OpenVtsSpacing.sm),
              _buildStatusDropdown(),
              const SizedBox(height: OpenVtsSpacing.sm),
              _buildPaymentModeDropdown(),
              const SizedBox(height: OpenVtsSpacing.sm),
              _buildDateRangeDropdown(),
              if (state.rangePreset == AdminPaymentsRangePreset.custom) ...[
                const SizedBox(height: OpenVtsSpacing.sm),
                _buildCustomDateRangeField(),
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildUserDropdown() {
    return _buildDropdownField<String?>(
      label: 'User',
      value: state.selectedUserId,
      options: [
        const _DropdownOption<String?>(value: null, label: 'All Users'),
        ...state.users.map((u) => _DropdownOption(
              value: u.id,
              label: _getUserLabel(u),
            )),
      ],
      onChanged: onUserChanged,
    );
  }

  Widget _buildStatusDropdown() {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : OpenVtsColors.textPrimary;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: OpenVtsTypography.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: OpenVtsSpacing.xs),
          _buildPillSegmentedControl<AdminPaymentStatus?>(
            context: context,
            segments: [
              _PillSegment<AdminPaymentStatus?>(value: null, label: 'All'),
              _PillSegment(
                value: AdminPaymentStatus.success,
                label: 'Success',
              ),
              _PillSegment(
                value: AdminPaymentStatus.pending,
                label: 'Pending',
              ),
              _PillSegment(
                value: AdminPaymentStatus.failed,
                label: 'Failed',
              ),
            ],
            selectedValue: state.selectedStatus,
            onChanged: onStatusChanged,
          ),
        ],
      );
    });
  }

  Widget _buildPaymentModeDropdown() {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final textColor = isDark ? Colors.white : OpenVtsColors.textPrimary;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Mode',
            style: OpenVtsTypography.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: OpenVtsSpacing.xs),
          _buildPillSegmentedControl<AdminPaymentMode?>(
            context: context,
            segments: [
              _PillSegment<AdminPaymentMode?>(value: null, label: 'All'),
              ...AdminPaymentMode.values.map((mode) => _PillSegment(
                    value: mode,
                    label: mode.label,
                  )),
            ],
            selectedValue: state.selectedMode,
            onChanged: onModeChanged,
          ),
        ],
      );
    });
  }

  Widget _buildDateRangeDropdown() {
    const options = [
      _DropdownOption(
        value: AdminPaymentsRangePreset.today,
        label: 'Today',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.yesterday,
        label: 'Yesterday',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.last12Hours,
        label: 'Last 12 Hours',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.last24Hours,
        label: 'Last 24 Hours',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.last7Days,
        label: 'Last 7 Days',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.last30Days,
        label: 'Last 30 Days',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.thisMonth,
        label: 'This Month',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.thisYear,
        label: 'This Year',
      ),
      _DropdownOption(
        value: AdminPaymentsRangePreset.custom,
        label: 'Custom Range',
      ),
    ];

    return _buildDropdownField<AdminPaymentsRangePreset>(
      label: 'Date Range',
      value: state.rangePreset,
      options: options,
      onChanged: (value) {
        if (value != null) {
          onRangePresetChanged(value);
        }
      },
    );
  }

  Widget _buildCustomDateRangeField() {
    return OpenVtsDateTimeRangeField(
      label: 'Custom Range',
      title: 'Choose Date Range',
      value: OpenVtsDateTimeRange(
        start: state.customFrom,
        end: state.customTo,
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      onChanged: (range) => onCustomRangeChanged(range.start, range.end),
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<_DropdownOption<T>> options,
    required ValueChanged<T?> onChanged,
  }) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final fillColor = isDark ? Colors.black : OpenVtsColors.surfaceElevated;
      final textColor = isDark ? Colors.white : OpenVtsColors.textPrimary;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: OpenVtsTypography.label.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: OpenVtsSpacing.xs),
          DropdownButtonFormField<T>(
            initialValue: value,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                borderSide: const BorderSide(color: OpenVtsColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                borderSide: const BorderSide(color: OpenVtsColors.border),
              ),
              filled: true,
              fillColor: fillColor,
            ),
            style: OpenVtsTypography.body.copyWith(
              color: textColor,
            ),
            dropdownColor: fillColor,
            items: options
                .map((opt) => DropdownMenuItem<T>(
                      value: opt.value,
                      child: Text(
                        opt.label,
                        style: TextStyle(color: textColor),
                      ),
                    ))
                .toList(growable: false),
            onChanged: onChanged,
            isExpanded: true,
          ),
        ],
      );
    });
  }

  String _getUserLabel(AdminUserListItem user) {
    final username = user.username.trim();
    final text = username.isEmpty ? user.name : '${user.name} (@$username)';
    return text;
  }

  Widget _buildPillSegmentedControl<T>({
    required BuildContext context,
    required List<_PillSegment<T>> segments,
    required T selectedValue,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outerBackgroundColor = isDark ? Colors.black : Colors.white;
    final outerBorderColor =
        isDark ? Colors.white : Colors.black.withValues(alpha: 0.2);

    return Container(
      decoration: BoxDecoration(
        color: outerBackgroundColor,
        border: Border.all(color: outerBorderColor, width: 1),
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(OpenVtsRadius.pill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < segments.length; i++) ...[
              Expanded(
                child: _buildPillSegment(
                  context: context,
                  segment: segments[i],
                  isSelected: segments[i].value == selectedValue,
                  isDark: isDark,
                  onTap: () => onChanged(segments[i].value),
                ),
              ),
              if (i < segments.length - 1)
                Container(
                  width: 1,
                  height: 32,
                  color: outerBorderColor,
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPillSegment<T>({
    required BuildContext context,
    required _PillSegment<T> segment,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final backgroundColor = isSelected
        ? (isDark ? Colors.black : Colors.white)
        : Colors.transparent;

    final textColor = isDark ? Colors.white : Colors.black;

    final borderColor =
        isDark ? Colors.white : Colors.black.withValues(alpha: 0.2);

    return Material(
      color: backgroundColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 34),
          padding: const EdgeInsets.symmetric(
            horizontal: OpenVtsSpacing.sm,
            vertical: OpenVtsSpacing.xs,
          ),
          decoration: isSelected
              ? BoxDecoration(
                  border: Border.all(color: borderColor, width: 1),
                  borderRadius: BorderRadius.circular(OpenVtsRadius.pill - 1),
                )
              : null,
          child: Center(
            child: Text(
              segment.label,
              style: OpenVtsTypography.meta.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownOption<T> {
  const _DropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}

class _PillSegment<T> {
  const _PillSegment({required this.value, required this.label});

  final T value;
  final String label;
}
