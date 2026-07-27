import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_client.dart';
import '../models/home_widgets.dart';

/// The two things Plane's workspace home holds that are the caller's own:
/// sticky notes and quick links.
///
/// Both are per-user. Neither view takes a parameter that would widen it past
/// the caller, and both set the owner server-side on create, so there is no
/// shape of request that reaches someone else's.
class HomeWidgetService {
  @visibleForTesting
  static Dio? debugClient;

  static Future<Dio> _client() async =>
      debugClient ?? await ApiClient.getInstance();

  static List _rows(Object? data) {
    if (data is Map && data.containsKey('results')) {
      return data['results'] as List;
    }
    return data is List ? data : const [];
  }

  // --- Stickies ------------------------------------------------------------

  static Future<List<Sticky>> getStickies(String workspaceSlug) async {
    final dio = await _client();
    final response = await dio.get('/workspaces/$workspaceSlug/stickies/');
    return _rows(response.data)
        .whereType<Map>()
        .map((e) => Sticky.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<Sticky> createSticky(
    String workspaceSlug, {
    String? name,
    String descriptionHtml = '<p></p>',
    String? backgroundColor,
  }) async {
    final dio = await _client();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/stickies/',
      data: {
        if (name != null) 'name': name,
        'description_html': descriptionHtml,
        if (backgroundColor != null) 'background_color': backgroundColor,
      },
    );
    return Sticky.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  static Future<void> updateSticky(
    String workspaceSlug,
    String stickyId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    await dio.patch('/workspaces/$workspaceSlug/stickies/$stickyId/',
        data: data);
  }

  static Future<void> deleteSticky(
      String workspaceSlug, String stickyId) async {
    final dio = await _client();
    await dio.delete('/workspaces/$workspaceSlug/stickies/$stickyId/');
  }

  // --- Quick links ---------------------------------------------------------

  static Future<List<QuickLink>> getQuickLinks(String workspaceSlug) async {
    final dio = await _client();
    final response = await dio.get('/workspaces/$workspaceSlug/quick-links/');
    return _rows(response.data)
        .whereType<Map>()
        .map((e) => QuickLink.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  static Future<QuickLink> createQuickLink(
    String workspaceSlug, {
    required String url,
    String? title,
  }) async {
    final dio = await _client();
    final response = await dio.post(
      '/workspaces/$workspaceSlug/quick-links/',
      data: {'url': url, if (title != null) 'title': title},
    );
    return QuickLink.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  static Future<void> updateQuickLink(
    String workspaceSlug,
    String linkId,
    Map<String, dynamic> data,
  ) async {
    final dio = await _client();
    await dio.patch('/workspaces/$workspaceSlug/quick-links/$linkId/',
        data: data);
  }

  static Future<void> deleteQuickLink(
      String workspaceSlug, String linkId) async {
    final dio = await _client();
    await dio.delete('/workspaces/$workspaceSlug/quick-links/$linkId/');
  }
}
