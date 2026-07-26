import '../config/api_client.dart';
import '../config/secure_storage.dart';
import '../models/notification.dart';

class NotificationService {
  /// Notifications are workspace-scoped on Plane: the routes are
  /// `workspaces/{slug}/users/notifications/...`. The bare `/users/...` paths
  /// this service used to call are not routes on either of Plane's APIs, so
  /// every call here returned 404.
  static Future<String> _base() async {
    final slug = await SecureStorage.getWorkspaceSlug() ?? '';
    return '/workspaces/$slug/users/notifications';
  }

  static Future<List<PlaneNotification>> getNotifications({
    String? type,
    bool? snoozed,
    bool? archived,
    bool? read,
  }) async {
    final dio = await ApiClient.getInstance();
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (snoozed != null) params['snoozed'] = snoozed;
    if (archived != null) params['archived'] = archived;
    if (read != null) params['read'] = read;

    final response = await dio.get(
      '${await _base()}/',
      queryParameters: params,
    );
    final data = response.data;
    List list;
    if (data is Map && data.containsKey('results')) {
      list = data['results'] as List;
    } else if (data is List) {
      list = data;
    } else {
      return [];
    }
    return list.map((e) => PlaneNotification.fromJson(e)).toList();
  }

  static Future<void> markAsRead(String notificationId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('${await _base()}/$notificationId/read/');
  }

  static Future<void> archive(String notificationId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('${await _base()}/$notificationId/archive/');
  }

  static Future<void> markAllAsRead() async {
    final dio = await ApiClient.getInstance();
    await dio.post('${await _base()}/mark-all-read/');
  }

  static Future<Map<String, dynamic>> getNotificationPreferences() async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/users/me/notification-preferences/');
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> updateNotificationPreferences(
      Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    final response =
        await dio.patch('/users/me/notification-preferences/', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }
}
