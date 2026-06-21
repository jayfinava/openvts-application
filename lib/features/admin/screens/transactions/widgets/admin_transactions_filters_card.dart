import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_radius.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../shared/widgets/open_vts_card.dart';
import '../../../../../shared/widgets/open_vts_date_time_range_selector.dart';
import '../../../models/admin_transactions_model.dart';
import '../../../models/admin_transactions_state.dart';

class AdminTransactionsFiltersCard extends StatelessWidget {
  const AdminTransactionsFiltersCard({
    required this.state,
    required this.onStatusChanged,
    required this.onModeChanged,
    required this.onTypeChanged,
    required this.onRangePresetChanged,
    required this.onCustomRangeChanged,
    required this.onClearFilters,
    required this.onApplyFilters,
    super.key,
  });

  final AdminTransactionsState state;
  final ValueChanged<AdminTransactionStatus?> onStatusChanged;
  final ValueChanged<AdminPaymentMode?> onModeChanged;
  final ValueChanged<AdminPaymentType?> onTypeChanged;
  final ValueChanged<AdminTransactionsRangePreset> onRangePresetChanged;
  final void Function(DateTime? from, DateTime? to) onCustomRangeChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onApplyFilters;

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
                  Icons.tune_rounded,
                  size: 18,
                  color: iconColor,
                ),
              ),
              const SizedBox(width: OpenVtsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: OpenVtsTypography.titleSmall.copyWith(
                        color: headingColor,
                      ),
                    ),
                    const SizedBox(height: OpenVtsSpacing.xxs),
                    Text(
                      'Refine transactions by status, mode, type, and date.',
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
                  onPressed: state.hasActiveFilters ? onClearFilters : null,
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
                  onPressed: onApplyFilters,
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Apply Filters'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    backgroundColor: OpenVtsColors.brandInk,
                    foregroundColor: OpenVtsColors.white,
                    side: const BorderSide(color: OpenVtsColors.white, width: 0.8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(OpenVtsRadius.md),
                    ),
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
                  Expanded(child: _buildStatusDropdown()),
                  const SizedBox(width: OpenVtsSpacing.sm),
                  Expanded(child: _buildPaymentModeDropdown()),
                ],
              ),
              const SizedBox(height: OpenVtsSpacing.sm),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildPaymentTypeDropdown()),
                  const SizedBox(width: OpenVtsSpacing.sm),
                  Expanded(child: _buildDateRangeDropdown()),
                ],
              ),
              if (state.rangePreset == AdminTransactionsRangePreset.custom) ...[
                const SizedBox(height: OpenVtsSpacing.sm),
                _buildCustomDateRangeField(),
              ],
            ],
          );
        } else {
          return Column(
            children: [
              _buildStatusDropdown(),
              const SizedBox(height: OpenVtsSpacing.sm),
              _buildPaymentModeDropdown(),
              const SizedBox(height: OpenVtsSpacing.sm),
              _buildPaymentTypeDropdown(),
              const SizedBox(height: OpenVtsSpacing.sm),
              _buildDateRangeDropdown(),
              if (state.rangePreset == AdminTransactionsRangePreset.custom) ...[
                const SizedBox(height: OpenVtsSpacing.sm),
                _buildCustomDateRangeField(),
              ],
            ],
          );
        }
      },
    );
  }

  Widget _buildStatusDropdown() {
    const options = [
      _DropdownOption<AdminTransactionStatus?>(value: null, label: 'All'),
      _DropdownOption(
        value: AdminTransactionStatus.success,
        label: 'Success',
      ),
      _DropdownOption(
        value: AdminTransactionStatus.pending,
        label: 'Pending',
      ),
      _DropdownOption(
        value: AdminTransactionStatus.failed,
        label: 'Failed',
      ),
    ];

    return _buildDropdownField<AdminTransactionStatus?>(
      label: 'Status',
      value: state.selectedStatus,
      options: options,
      onChanged: onStatusChanged,
    );
  }

  Widget _buildPaymentModeDropdown() {
    final options = <_DropdownOption<AdminPaymentMode?>>[
      const _DropdownOption<AdminPaymentMode?>(value: null, label: 'All'),
      ...AdminPaymentMode.values.map((mode) => _DropdownOption(
            value: mode,
            label: mode.label,
          )),
    ];

    return _buildDropdownField<AdminPaymentMode?>(
      label: 'Payment Mode',
      value: state.selectedMode,
      options: options,
      onChanged: onModeChanged,
    );
  }

  Widget _buildPaymentTypeDropdown() {
    const options = [
      _DropdownOption<AdminPaymentType?>(value: null, label: 'All'),
      _DropdownOption(value: AdminPaymentType.credit, label: 'Credit'),
      _DropdownOption(value: AdminPaymentType.debit, label: 'Debit'),
    ];

    return _buildDropdownField<AdminPaymentType?>(
      label: 'Payment Type',
      value: state.selectedType,
      options: options,
      onChanged: onTypeChanged,
    );
  }

  Widget _buildDateRangeDropdown() {
    const options = [
      _DropdownOption(
        value: AdminTransactionsRangePreset.today,
        label: 'Today',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.yesterday,
        label: 'Yesterday',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.last12Hours,
        label: 'Last 12 Hours',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.last24Hours,
        label: 'Last 24 Hours',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.last7Days,
        label: 'Last 7 Days',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.last30Days,
        label: 'Last 30 Days',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.thisMonth,
        label: 'This Month',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.thisYear,
        label: 'This Year',
      ),
      _DropdownOption(
        value: AdminTransactionsRangePreset.custom,
        label: 'Custom Range',
      ),
    ];

    return _buildDropdownField<AdminTransactionsRangePreset>(
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
}

class _DropdownOption<T> {
  const _DropdownOption({required this.value, required this.label});

  final T value;
  final String label;
}
