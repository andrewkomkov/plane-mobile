import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../config/secure_storage.dart';
import '../models/notification.dart';

class NotificationService {
  /// Injected by tests in place of a real HTTP client, the same seam
  /// [AnalyticsService] uses. The notification list is the one screen whose
  /// accessibility can only be checked with rows on it.
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async {
    final injected = debugClient;
    if (injected != null) return injected;
    return ApiClient.getInstance();
  }

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
    final dio = await _client();
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
    final dio = await _client();
    await dio.post('${await _base()}/$notificationId/read/');
  }

  /// Puts a notification back in the unread pile.
  ///
  /// Same path as [markAsRead], distinguished by method —
  /// `NotificationViewSet.as_view({"post": "mark_read", "delete":
  /// "mark_unread"})` — which is the same shape [unarchive] uses and reads
  /// just as wrongly: this is not a delete of the notification.
  static Future<void> markAsUnread(String notificationId) async {
    final dio = await _client();
    await dio.delete('${await _base()}/$notificationId/read/');
  }

  static Future<void> archive(String notificationId) async {
    final dio = await _client();
    await dio.post('${await _base()}/$notificationId/archive/');
  }

  /// Puts an archived notification back in the feed.
  ///
  /// Plane routes both directions through the same path and distinguishes them
  /// by method — `NotificationViewSet.as_view({"post": "archive", "delete":
  /// "unarchive"})` — so this is a DELETE on the archive endpoint and not, as
  /// it reads, a delete of the notification. That is the whole reason the
  /// swipe in the feed can offer an undo.
  static Future<void> unarchive(String notificationId) async {
    final dio = await _client();
    await dio.delete('${await _base()}/$notificationId/archive/');
  }

  static Future<void> markAllAsRead() async {
    final dio = await _client();
    await dio.post('${await _base()}/mark-all-read/');
  }

  static Future<Map<String, dynamic>> getNotificationPreferences() async {
    final dio = await _client();
    final response = await dio.get('/users/me/notification-preferences/');
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<Map<String, dynamic>> updateNotificationPreferences(
      Map<String, dynamic> data) async {
    final dio = await _client();
    final response =
        await dio.patch('/users/me/notification-preferences/', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }
}
