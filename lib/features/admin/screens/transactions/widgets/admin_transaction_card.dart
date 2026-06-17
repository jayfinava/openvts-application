import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../core/utils/date_time_formatter.dart';
import '../../../../../shared/helpers/toast_helper.dart';
import '../../../../../shared/widgets/open_vts_card.dart';
import '../../../../../shared/widgets/open_vts_status_chip.dart';
import '../../../models/admin_transactions_model.dart';

class AdminTransactionCard extends StatelessWidget {
  const AdminTransactionCard({
    required this.transaction,
    required this.onTap,
    super.key,
  });

  final AdminTransaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = const DateTimeFormatter();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimaryColor =
        isDark ? OpenVtsColors.darkTextPrimary : OpenVtsColors.textPrimary;
    final textSecondaryColor =
        isDark ? OpenVtsColors.darkTextSecondary : OpenVtsColors.textSecondary;

    return OpenVtsCard(
      onTap: onTap,
      padding: const EdgeInsets.all(OpenVtsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  transaction.amountDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: OpenVtsTypography.numeric.copyWith(
                    fontSize: 22,
                    color: textPrimaryColor,
                  ),
                ),
              ),
              OpenVtsStatusChip(
                label: transaction.status.label,
                type: _statusType(transaction.status),
              ),
            ],
          ),
          const SizedBox(height: OpenVtsSpacing.xs),
          _row(
            icon: Icons.calendar_today_rounded,
            label: transaction.createdAt == null
                ? (transaction.createdAtRaw.trim().isEmpty
                    ? '-'
                    : transaction.createdAtRaw)
                : formatter.formatDateTime(transaction.createdAt!.toLocal()),
            textSecondaryColor: textSecondaryColor,
          ),
          _row(
              icon: Icons.payments_outlined,
              label: 'Mode: ${transaction.paymentMode.label}',
              textSecondaryColor: textSecondaryColor),
          _row(
              icon: Icons.compare_arrows_rounded,
              label: 'Type: ${transaction.paymentType.label}',
              textSecondaryColor: textSecondaryColor),
          _copyRow(context,
              icon: Icons.tag_rounded,
              label: 'Reference',
              value: transaction.referenceDisplay,
              textSecondaryColor: textSecondaryColor),
          _row(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Provider: ${transaction.providerDisplay}',
              textSecondaryColor: textSecondaryColor),
          _row(
              icon: Icons.person_outline_rounded,
              label: 'Counterparty: ${transaction.counterpartyName}',
              textSecondaryColor: textSecondaryColor),
          _row(
              icon: Icons.badge_outlined,
              label: 'Recorded By: ${transaction.recordedByName}',
              textSecondaryColor: textSecondaryColor),
          _copyRow(context,
              icon: Icons.numbers_rounded,
              label: 'Transaction ID',
              value: transaction.id,
              textSecondaryColor: textSecondaryColor),
        ],
      ),
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required Color textSecondaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: OpenVtsSpacing.xxs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: textSecondaryColor),
          const SizedBox(width: OpenVtsSpacing.xs),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenVtsTypography.meta
                  .copyWith(color: textSecondaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color textSecondaryColor,
  }) {
    final normalized = value.trim();
    final display = normalized.isEmpty || normalized == '—' ? '-' : normalized;

    return Padding(
      padding: const EdgeInsets.only(top: OpenVtsSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: textSecondaryColor),
          const SizedBox(width: OpenVtsSpacing.xs),
          Expanded(
            child: Text(
              '$label: $display',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: OpenVtsTypography.meta
                  .copyWith(color: textSecondaryColor),
            ),
          ),
          if (display != '-')
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: display));
                ToastHelper.showSuccess('$label copied', context: context);
              },
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.copy_rounded,
                    size: 14, color: textSecondaryColor),
              ),
            ),
        ],
      ),
    );
  }

  OpenVtsStatusType _statusType(AdminTransactionStatus status) {
    return switch (status) {
      AdminTransactionStatus.success => OpenVtsStatusType.success,
      AdminTransactionStatus.pending => OpenVtsStatusType.warning,
      AdminTransactionStatus.failed => OpenVtsStatusType.error,
    };
  }
}
