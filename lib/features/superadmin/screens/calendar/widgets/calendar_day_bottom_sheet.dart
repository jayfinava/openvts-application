import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/open_vts_colors.dart';
import '../../../../../core/theme/open_vts_spacing.dart';
import '../../../../../core/theme/open_vts_typography.dart';
import '../../../../../shared/widgets/open_vts_card.dart';
import '../../../../../shared/widgets/open_vts_empty_state.dart';
import '../../../../../shared/widgets/open_vts_error_view.dart';
import '../../../../../shared/widgets/open_vts_loader.dart';
import '../../../controllers/superadmin_calendar_controller.dart';
import '../../../models/superadmin_calendar_model.dart';

class CalendarDayBottomSheet extends ConsumerWidget {
  final DateTime date;

  const CalendarDayBottomSheet({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(calendarDayDetailsProvider(date));

    return detailsAsync.when(
      loading: () => const Center(child: OpenVtsLoader()),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.all(OpenVtsSpacing.md),
        child: OpenVtsErrorView(
          message: 'Failed to load details',
          onRetry: () => ref.refresh(calendarDayDetailsProvider(date)),
        ),
      ),
      data: (details) {
        if (details.isEmpty) {
          return const OpenVtsEmptyState(
            title: 'No Data',
            message: 'There are no events on this day',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            OpenVtsSpacing.md,
            OpenVtsSpacing.md,
            OpenVtsSpacing.md,
            OpenVtsSpacing.lg,
          ),
          itemCount: details.length,
          separatorBuilder: (context, index) => const SizedBox(height: OpenVtsSpacing.sm),
          itemBuilder: (context, index) => _CalendarDayEventTile(detail: details[index]),
        );
      },
    );
  }
}

class _CalendarDayEventTile extends ConsumerWidget {
  const _CalendarDayEventTile({required this.detail});

  final CalendarDayDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final linkedDetailAsync = detail.isUser
        ? ref.watch(calendarUserDetailsProvider(detail.userId!))
        : detail.isVehicle
            ? ref.watch(calendarVehicleDetailsProvider(detail.vehicleId!))
            : const AsyncValue<CalendarLinkedDetail?>.data(null);

    final linkedDetail = linkedDetailAsync.asData?.value;
    final title = _resolveTitle(detail, linkedDetail);
    final subtitle = _resolveSubtitle(detail, linkedDetail);
    final metadata = linkedDetail?.metadata ?? const <String>[];

    return OpenVtsCard(
      padding: const EdgeInsets.all(OpenVtsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventTypeIcon(type: detail.type),
          const SizedBox(width: OpenVtsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OpenVtsTypography.label.copyWith(
                          color: isDark
                              ? OpenVtsColors.darkTextPrimary
                              : OpenVtsColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (detail.count > 1) ...[
                      const SizedBox(width: OpenVtsSpacing.xs),
                      _CountBadge(count: detail.count),
                    ],
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: OpenVtsTypography.meta.copyWith(
                      color: isDark
                          ? OpenVtsColors.darkTextSecondary
                          : OpenVtsColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (metadata.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final item in metadata.take(2))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: OpenVtsTypography.meta.copyWith(
                          color: isDark
                              ? OpenVtsColors.darkTextSecondary.withValues(alpha: 0.7)
                              : OpenVtsColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          if (linkedDetailAsync.isLoading)
            const Padding(
              padding: EdgeInsetsDirectional.only(start: OpenVtsSpacing.sm),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.6),
              ),
            ),
        ],
      ),
    );
  }

  String _resolveTitle(
    CalendarDayDetail detail,
    CalendarLinkedDetail? linkedDetail,
  ) {
    if (detail.title.trim().isNotEmpty && detail.title != 'Users' && detail.title != 'Vehicle') {
      return detail.title;
    }
    if (linkedDetail != null && linkedDetail.title.trim().isNotEmpty) {
      return linkedDetail.title;
    }
    return detail.title;
  }

  String _resolveSubtitle(
    CalendarDayDetail detail,
    CalendarLinkedDetail? linkedDetail,
  ) {
    if (detail.subtitle.trim().isNotEmpty) {
      return detail.subtitle;
    }
    return linkedDetail?.subtitle ?? '';
  }
}

class _EventTypeIcon extends StatelessWidget {
  const _EventTypeIcon({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    late final IconData icon;
    late final Color color;

    switch (type) {
      case 'vehicle':
        icon = Icons.directions_car_outlined;
        color = OpenVtsColors.success;
      case 'expiry':
        icon = Icons.warning_amber_rounded;
        color = OpenVtsColors.error;
      case 'users':
      default:
        icon = Icons.person_outline_rounded;
        color = OpenVtsColors.brandInk;
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? OpenVtsColors.white.withValues(alpha: 0.12)
            : OpenVtsColors.brandInk.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark
              ? OpenVtsColors.white.withValues(alpha: 0.25)
              : OpenVtsColors.brandInk.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Text(
        '$count',
        style: OpenVtsTypography.meta.copyWith(
          color: isDark
              ? OpenVtsColors.darkTextPrimary
              : OpenVtsColors.brandInk,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
