import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/error_mapper.dart';
import '../../../../shared/helpers/mobile_text.dart';
import '../../../../shared/helpers/toast_helper.dart';
import '../../../../shared/widgets/open_vts_detail_tab_strip.dart';
import '../../../../shared/widgets/open_vts_page_scaffold.dart';
import '../../../notifications/controllers/notification_center_controller.dart';
import '../../../notifications/models/notification_center_state.dart';
import '../../../notifications/widgets/notification_center_view.dart';
import '../../controllers/user_providers.dart';

class UserNotificationsScreen extends ConsumerStatefulWidget {
  const UserNotificationsScreen({super.key});
  @override
  ConsumerState<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState
    extends ConsumerState<UserNotificationsScreen> {
  var _tab = 0;
  @override
  Widget build(BuildContext context) {
    final vehicle = ref.watch(userVehicleNotificationCenterProvider);
    final user = ref.watch(userNotificationCenterProvider);
    return OpenVtsPageScaffold(
      title: context.mobileText('Notifications'),
      headerMode: OpenVtsPageHeaderMode.closeable,
      body: Column(children: [
        OpenVtsDetailTabStrip<int>(
            selected: _tab,
            onChanged: (tab) => setState(() => _tab = tab),
            tabs: [
              OpenVtsDetailTabOption(
                  value: 0,
                  label: '${context.mobileText('Vehicle')} (${vehicle.unreadCount})',
                  icon: Icons.directions_car_outlined),
              OpenVtsDetailTabOption(
                  value: 1,
                  label: '${context.mobileText('User')} (${user.unreadCount})',
                  icon: Icons.person_outline),
            ]),
        const SizedBox(height: 12),
        Expanded(
            child: IndexedStack(index: _tab, children: [
          _inbox(
              vehicle,
              ref.read(userVehicleNotificationCenterProvider.notifier),
              'vehicle-inbox'),
          _inbox(user, ref.read(userNotificationCenterProvider.notifier),
              'user-inbox'),
        ])),
      ]),
    );
  }

  Widget _inbox(NotificationCenterState state,
          NotificationCenterController controller, String key) =>
      NotificationCenterView(
          key: PageStorageKey(key),
          state: state,
          onRefresh: controller.refresh,
          onRetry: controller.load,
          onLoadMore: controller.loadMore,
          onUnreadOnlyChanged: controller.setUnreadOnly,
          onMarkAllAsRead: () async {
            try {
              final hadUnread = state.unreadCount > 0;
              await controller.markAllAsRead();
              if (!mounted) return;
              ref.invalidate(userNotificationUnreadBadgeProvider);
              if (hadUnread) {
                ToastHelper.showSuccess(
                    context.mobileText('All notifications marked as read.'));
              }
            } catch (error) {
              if (mounted) {
                ToastHelper.showError(ErrorMapper.from(error).message);
              }
            }
          },
          onMarkAsRead: (id) async {
            try {
              await controller.markAsRead(id);
              if (mounted) ref.invalidate(userNotificationUnreadBadgeProvider);
            } catch (error) {
              if (mounted) {
                ToastHelper.showError(ErrorMapper.from(error).message);
              }
            }
          });
}
