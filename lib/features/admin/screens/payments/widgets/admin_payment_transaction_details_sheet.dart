import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../core/utils/date_time_formatter.dart';
import '../../../../../shared/widgets/open_vts_card.dart';
import '../../../models/admin_payments_model.dart';

class AdminPaymentTransactionDetailsSheet extends StatelessWidget {
  const AdminPaymentTransactionDetailsSheet({required this.item, super.key});

  final AdminPaymentTransaction item;

  @override
  Widget build(BuildContext context) {
    final formatter = const DateTimeFormatter();
    final date = item.createdAt == null
        ? item.createdAtRaw
        : formatter.formatDateTime(item.createdAt!.toLocal());
    final textColor = Theme.of(context).colorScheme.onSurface;

    return ListView(
      controller: PrimaryScrollController.maybeOf(context),
      padding: const EdgeInsets.all(OpenVtsSpacing.md),
      children: [
        OpenVtsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transaction ID: ${item.id.isEmpty ? '-' : item.id}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('Amount: ${item.amountDisplay}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('Status: ${item.status.label}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('Created: ${date.trim().isEmpty ? '-' : date}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text(
                  'Payment Type: ${item.paymentType.isEmpty ? '-' : item.paymentType}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('Payment Mode: ${item.paymentMode.label}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text(
                  'Reference: ${item.reference.isEmpty ? '-' : item.reference}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('Provider: ${item.provider.isEmpty ? '-' : item.provider}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text(
                  'Provider Ref: ${item.providerRef.isEmpty ? '-' : item.providerRef}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('From: ${item.fromUser?.displayName ?? '-'}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('To: ${item.toUser?.displayName ?? '-'}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text('Recorded By: ${item.recordedBy?.displayName ?? '-'}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text(
                  'Vehicle: ${item.vehicle['name']?.toString() ?? item.vehicle['plateNumber']?.toString() ?? '-'}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text(
                  'Failure Code: ${item.failureCode.isEmpty ? '-' : item.failureCode}', style: OpenVtsTypography.body.copyWith(color: textColor)),
              Text(
                  'Failure Message: ${item.failureMessage.isEmpty ? '-' : item.failureMessage}', style: OpenVtsTypography.body.copyWith(color: textColor)),
            ],
          ),
        ),
        if (item.meta.isNotEmpty) ...[
          const SizedBox(height: OpenVtsSpacing.sm),
          OpenVtsCard(
            child: SelectableText(
                const JsonEncoder.withIndent('  ').convert(item.meta),
                style: TextStyle(color: textColor)),
          ),
        ],
      ],
    );
  }
}
