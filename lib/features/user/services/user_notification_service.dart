import '../../../core/api/api_endpoints.dart';
import '../../notifications/services/notification_service.dart';

class UserNotificationService extends NotificationService {
  UserNotificationService(super.apiClient, {this.vehicleFeed = false});

  final bool vehicleFeed;
  @override
  bool get cursorIsContinuation => vehicleFeed;

  @override
  String get listEndpoint => vehicleFeed
      ? ApiEndpoints.user.vehicleNotifications
      : ApiEndpoints.user.notifications;

  @override
  String notificationReadEndpoint(int id) {
    return vehicleFeed
        ? ApiEndpoints.user.vehicleNotificationRead(id.toString())
        : ApiEndpoints.user.notificationRead(id.toString());
  }

  @override
  String get readAllEndpoint => vehicleFeed
      ? ApiEndpoints.user.vehicleNotificationsReadAll
      : ApiEndpoints.user.notificationsReadAll;

  @override
  String get roleLabel => 'User';
}
