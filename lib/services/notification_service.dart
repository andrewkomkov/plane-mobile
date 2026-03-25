import '../config/api_client.dart';
import '../models/notification.dart';

class NotificationService {
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
      '/users/notifications/',
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
    await dio.post('/users/notifications/$notificationId/read/');
  }

  static Future<void> archive(String notificationId) async {
    final dio = await ApiClient.getInstance();
    await dio.post('/users/notifications/$notificationId/archive/');
  }

  static Future<void> markAllAsRead() async {
    final dio = await ApiClient.getInstance();
    await dio.post('/users/notifications/mark-all-read/');
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
